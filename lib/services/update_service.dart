import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class UpdateManifest {
  UpdateManifest(this.versionCode, this.versionName, this.url, this.size,
      this.sha256Value, this.notes);
  final int versionCode;
  final String versionName;
  final Uri url;
  final int size;
  final String sha256Value;
  final String notes;

  factory UpdateManifest.parse(Map<String, dynamic> json,
      {required bool allowLan}) {
    if (json['schemaVersion'] != 1 ||
        json['applicationId'] != 'com.example.course_table' ||
        json['versionCode'] is! int ||
        (json['versionCode'] as int) <= 0 ||
        json['versionName'] is! String ||
        json['size'] is! int ||
        (json['size'] as int) <= 0 ||
        (json['size'] as int) > 512 * 1024 * 1024 ||
        json['sha256'] is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(json['sha256'] as String) ||
        json['apkUrl'] is! String) {
      throw const FormatException('版本文件格式错误');
    }
    final Uri url = Uri.parse(json['apkUrl'] as String);
    validateUpdateUrl(url, allowLan: allowLan);
    return UpdateManifest(
        json['versionCode'] as int,
        json['versionName'] as String,
        url,
        json['size'] as int,
        (json['sha256'] as String).toLowerCase(),
        json['notes'] as String? ?? '');
  }
}

void validateUpdateUrl(Uri uri, {required bool allowLan}) {
  final List<int>? ip = InternetAddress.tryParse(uri.host)?.rawAddress;
  final bool private = ip != null &&
      ip.length == 4 &&
      (ip[0] == 10 ||
          (ip[0] == 192 && ip[1] == 168) ||
          (ip[0] == 172 && ip[1] >= 16 && ip[1] <= 31) ||
          ip[0] == 127);
  if (uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      !(uri.scheme == 'https' ||
          (allowLan && private && uri.scheme == 'http'))) {
    throw const FormatException('正式更新仅允许 HTTPS；Debug HTTP 仅允许局域网 IPv4 地址');
  }
}

class UpdateService {
  UpdateService({Future<Directory> Function()? temporaryDirectory})
      : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;
  final Future<Directory> Function() _temporaryDirectory;
  static const MethodChannel channel = MethodChannel('course_table/updates');
  static const String configuredUrl =
      String.fromEnvironment('UPDATE_MANIFEST_URL');
  static const bool allowLan = kDebugMode;
  HttpClient? _client;
  bool _cancelled = false;
  void Function()? _cancelRead;

  Future<Map<dynamic, dynamic>> info() async =>
      (await channel.invokeMapMethod<dynamic, dynamic>('info'))!;

  void cancel() {
    _cancelled = true;
    _cancelRead?.call();
    _client?.close(force: true);
  }

  Stream<List<int>> _read(HttpClientResponse response, Duration timeout) {
    late StreamSubscription<List<int>> subscription;
    late StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () {
        subscription = response.timeout(timeout).listen(controller.add,
            onError: controller.addError, onDone: controller.close);
        _cancelRead = () {
          controller.addError(const HttpException('操作已取消'));
          unawaited(subscription.cancel());
          unawaited(controller.close());
          _cancelRead = null;
        };
        if (_cancelled) {
          _cancelRead?.call();
        }
      },
      onCancel: () {
        _cancelRead = null;
        return subscription.cancel();
      },
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
    );
    return controller.stream;
  }

  Future<HttpClientResponse> _get(Uri uri) async {
    // Follow redirects manually so HTTPS can never downgrade to HTTP.
    for (int redirects = 0; redirects <= 5; redirects++) {
      validateUpdateUrl(uri, allowLan: allowLan);
      final HttpClientRequest request =
          await _client!.getUrl(uri).timeout(const Duration(seconds: 20));
      request.followRedirects = false;
      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 20));
      if (<int>[301, 302, 303, 307, 308].contains(response.statusCode)) {
        final String? location = response.headers.value('location');
        if (location == null) {
          throw const HttpException('重定向缺少地址');
        }
        uri = uri.resolve(location);
        await response.drain<void>().timeout(const Duration(seconds: 10));
        continue;
      }
      if (response.statusCode != 200) {
        throw HttpException('服务器返回 ${response.statusCode}');
      }
      return response;
    }
    throw const HttpException('重定向次数过多');
  }

  Future<UpdateManifest> check(String address) async {
    _cancelled = false;
    _client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final HttpClientResponse response = await _get(Uri.parse(address));
      final List<int> bytes = <int>[];
      await for (final List<int> chunk
          in _read(response, const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > 64 * 1024) {
          throw const FormatException('版本文件过大');
        }
      }
      return UpdateManifest.parse(
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
          allowLan: allowLan);
    } finally {
      _client?.close(force: true);
      _client = null;
    }
  }

  Future<File> download(
      UpdateManifest manifest, void Function(double) progress) async {
    _cancelled = false;
    final Directory cache = await _temporaryDirectory();
    final Directory directory =
        await Directory('${cache.path}/updates').create(recursive: true);
    final File partial = File('${directory.path}/update.part');
    final File apk = File('${directory.path}/update.apk');
    _client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    IOSink? sink;
    try {
      if (apk.existsSync()) {
        await apk.delete();
      }
      final HttpClientResponse response = await _get(manifest.url);
      if (response.contentLength >= 0 &&
          response.contentLength != manifest.size) {
        throw const FormatException('下载大小与版本文件不符');
      }
      sink = partial.openWrite();
      int received = 0;
      await for (final List<int> chunk
          in _read(response, const Duration(seconds: 30))) {
        if (_cancelled) {
          throw const HttpException('下载已取消');
        }
        received += chunk.length;
        if (received > manifest.size) {
          throw const FormatException('APK 超出预期大小');
        }
        sink.add(chunk);
        await sink.flush();
        progress(received / manifest.size);
      }
      await sink.close();
      sink = null;
      if (_cancelled ||
          received != manifest.size ||
          (await sha256.bind(partial.openRead()).first).toString() !=
              manifest.sha256Value) {
        throw const FormatException('下载不完整或 SHA256 校验失败，请重试');
      }
      return await partial.rename(apk.path);
    } finally {
      await sink?.close();
      if (partial.existsSync()) {
        await partial.delete();
      }
      _client?.close(force: true);
      _client = null;
    }
  }

  Future<String?> install(File apk, UpdateManifest manifest) =>
      channel.invokeMethod<String>('install', <String, Object>{
        'path': apk.path,
        'versionCode': manifest.versionCode
      });
}
