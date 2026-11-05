import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/update_service.dart';

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});
  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  final UpdateService _service = UpdateService();
  final TextEditingController _address =
      TextEditingController(text: UpdateService.configuredUrl);
  Map<dynamic, dynamic>? _info;
  UpdateManifest? _manifest;
  File? _apk;
  bool _busy = false;
  double? _progress;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _service.info().then((Map<dynamic, dynamic> info) {
      if (mounted) {
        setState(() => _info = info);
      }
    }).catchError((Object error) {
      if (mounted) {
        setState(() => _status = '读取版本失败：$error');
      }
    });
  }

  @override
  void dispose() {
    _service.cancel();
    _address.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _status = '操作未完成，可重试：$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _check() => _run(() async {
        setState(() {
          _manifest = null;
          _apk = null;
        });
        final Map<dynamic, dynamic> current = await _service.info();
        final UpdateManifest next = await _service.check(_address.text.trim());
        if (!mounted) {
          return;
        }
        setState(() {
          _info = current;
          if (next.versionCode > (current['versionCode'] as int)) {
            _manifest = next;
            _status =
                '发现新版本 ${next.versionName}，${(next.size / 1048576).toStringAsFixed(1)} MB';
          } else {
            _status = '当前已是最新版本';
          }
        });
      });

  Future<void> _download() async {
    final UpdateManifest manifest = _manifest!;
    final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
                title: const Text('下载更新'),
                content: Text(
                    '${manifest.versionName}\n${manifest.notes}\n\n更新前建议导出课程备份。下载完成后仍需您确认安装。'),
                actions: <Widget>[
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('下载'))
                ]));
    if (confirmed != true || !mounted) {
      return;
    }
    await _run(() async {
      final File file = await _service.download(manifest, (double value) {
        if (mounted) {
          setState(() => _progress = value);
        }
      });
      if (mounted) {
        setState(() {
          _apk = file;
          _status = '下载及 SHA256 校验完成，请点击安装更新';
        });
      }
    });
  }

  Future<void> _install() => _run(() async {
        final String? result = await _service.install(_apk!, _manifest!);
        if (mounted) {
          setState(() => _status = result == 'permission'
              ? '请允许此来源安装应用，返回后再次点击安装更新。'
              : '已打开系统安装界面。取消后可继续使用当前版本，也可再次点击安装。');
        }
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('版本与更新')),
        body: ListView(padding: const EdgeInsets.all(20), children: <Widget>[
          Text(_info == null
              ? '读取版本中…'
              : '当前版本 ${_info!['versionName']} (${_info!['versionCode']})'),
          if (_info != null)
            SelectableText(
                '包名：${_info!['applicationId']}\n签名 SHA256：${(_info!['certificates'] as List<dynamic>).join(', ')}'),
          const SizedBox(height: 20),
          if (UpdateService.allowLan)
            TextField(
                controller: _address,
                enabled: !_busy,
                decoration: const InputDecoration(
                    labelText: 'Debug 测试版本信息地址',
                    hintText: 'http://电脑局域网IP:8765/version.json')),
          if (!UpdateService.allowLan && UpdateService.configuredUrl.isEmpty)
            const Text('线上更新尚未配置，当前版本可正常使用。'),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: _busy ||
                      (!UpdateService.allowLan &&
                          UpdateService.configuredUrl.isEmpty)
                  ? null
                  : _check,
              child: const Text('检查更新')),
          if (_manifest != null) ...<Widget>[
            Text(_manifest!.notes),
            if (_apk == null)
              OutlinedButton(
                  onPressed: _busy ? null : _download,
                  child: const Text('下载更新 / 重试')),
            if (_apk != null)
              FilledButton(
                  onPressed: _busy ? null : _install,
                  child: const Text('安装更新')),
          ],
          if (_busy) LinearProgressIndicator(value: _progress),
          if (_progress != null)
            Text('${(_progress! * 100).toStringAsFixed(0)}%'),
          if (_busy)
            TextButton(onPressed: _service.cancel, child: const Text('取消网络操作')),
          const SizedBox(height: 12),
          Text(_status),
          const SizedBox(height: 20),
          const Text('下载或安装取消不会删除课程和设置。系统仅允许签名兼容的新版覆盖安装；不要为解决安装失败而卸载应用。'),
        ]),
      );
}
