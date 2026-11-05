import 'dart:convert';
import 'dart:io';
import 'package:course_table/services/update_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late Directory directory;
  late UpdateService service;
  late Map<String, dynamic> metadata;
  late List<int> payload;
  int downloadAttempts = 0;

  setUp(() async {
    payload = utf8.encode('test APK bytes');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    directory = await Directory.systemTemp.createTemp('update_test_');
    service = UpdateService(temporaryDirectory: () async => directory);
    metadata = <String, dynamic>{
      'schemaVersion': 1,
      'applicationId': 'com.example.course_table',
      'versionCode': 4,
      'versionName': '1.2.0',
      'apkUrl': 'http://127.0.0.1:${server.port}/app.apk',
      'size': payload.length,
      'sha256': sha256.convert(payload).toString(),
    };
    downloadAttempts = 0;
    server.listen((HttpRequest request) async {
      if (request.uri.path == '/version.json') {
        request.response.write(jsonEncode(metadata));
      } else if (request.uri.path == '/retry.apk' && downloadAttempts++ == 0) {
        request.response.statusCode = 503;
      } else if (request.uri.path == '/redirect') {
        request.response.statusCode = 302;
        request.response.headers.set('location', 'http://example.com/unsafe');
      } else if (request.uri.path == '/slow.apk') {
        request.response.bufferOutput = false;
        request.response.contentLength = payload.length;
        request.response.add(payload.take(1).toList());
        await request.response.flush();
        return;
      } else {
        request.response.contentLength = payload.length;
        request.response.add(payload);
      }
      await request.response.close();
    });
  });
  tearDown(() async {
    service.cancel();
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  test('Release URL policy rejects LAN, cleartext and URL credentials', () {
    for (final String url in <String>[
      'http://192.168.1.2/a',
      'http://example.com/a',
      'https://user:pass@example.com/a'
    ]) {
      expect(() => validateUpdateUrl(Uri.parse(url), allowLan: false),
          throwsFormatException);
    }
    validateUpdateUrl(Uri.parse('https://downloads.example.com/version.json'),
        allowLan: false);
  });
  test('Debug permits private IPv4 HTTP only', () {
    validateUpdateUrl(Uri.parse('http://192.168.1.2/a'), allowLan: true);
    expect(
        () => validateUpdateUrl(Uri.parse('http://example.com/a'),
            allowLan: true),
        throwsFormatException);
  });
  test('Reject wrong application ID and malformed manifest', () {
    metadata['applicationId'] = 'another.app';
    expect(() => UpdateManifest.parse(metadata, allowLan: true),
        throwsFormatException);
    metadata['applicationId'] = 'com.example.course_table';
    metadata['sha256'] = 'bad';
    expect(() => UpdateManifest.parse(metadata, allowLan: true),
        throwsFormatException);
  });
  test('Fetch JSON and verify downloaded bytes', () async {
    final UpdateManifest manifest =
        await service.check('http://127.0.0.1:${server.port}/version.json');
    final File file = await service.download(manifest, (_) {});
    expect(await file.readAsBytes(), payload);
    expect(File('${directory.path}/updates/update.part').existsSync(), false);
  });
  test('Streaming large response preserves backpressure and full hash',
      () async {
    payload = List<int>.generate(4 * 1024 * 1024, (int i) => i % 251);
    metadata['size'] = payload.length;
    metadata['sha256'] = sha256.convert(payload).toString();
    final File file = await service.download(
        UpdateManifest.parse(metadata, allowLan: true), (_) {});
    expect(await file.length(), payload.length);
    expect((await sha256.bind(file.openRead()).first).toString(),
        metadata['sha256']);
  });

  test('Corrupted hash never leaves installable APK', () async {
    metadata['sha256'] = '0' * 64;
    await expectLater(
        service.download(
            UpdateManifest.parse(metadata, allowLan: true), (_) {}),
        throwsFormatException);
    expect(File('${directory.path}/updates/update.apk').existsSync(), false);
    expect(File('${directory.path}/updates/update.part').existsSync(), false);
  });
  test('Failed download can retry successfully', () async {
    metadata['apkUrl'] = 'http://127.0.0.1:${server.port}/retry.apk';
    final UpdateManifest manifest =
        UpdateManifest.parse(metadata, allowLan: true);
    await expectLater(
        service.download(manifest, (_) {}), throwsA(isA<HttpException>()));
    expect(await (await service.download(manifest, (_) {})).readAsBytes(),
        payload);
  });
  test('Redirect to public cleartext is rejected', () async {
    await expectLater(service.check('http://127.0.0.1:${server.port}/redirect'),
        throwsFormatException);
  });
  test('Cancellation deletes partial download and permits retry', () async {
    metadata['apkUrl'] = 'http://127.0.0.1:${server.port}/slow.apk';
    await expectLater(
        service.download(UpdateManifest.parse(metadata, allowLan: true),
            (_) => service.cancel()),
        throwsA(anything));
    expect(File('${directory.path}/updates/update.part').existsSync(), false);
    metadata['apkUrl'] = 'http://127.0.0.1:${server.port}/app.apk';
    expect(
        await (await service.download(
                UpdateManifest.parse(metadata, allowLan: true), (_) {}))
            .readAsBytes(),
        payload);
  });
}
