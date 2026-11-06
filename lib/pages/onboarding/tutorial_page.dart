import 'package:flutter/material.dart';
import '../settings/semester_settings_page.dart';

/// 老用户只在设置中主动查看；重看教程不读写课程、学期或偏好。
class TutorialPage extends StatelessWidget {
  const TutorialPage({super.key, this.isFirstUse = false});
  final bool isFirstUse;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(isFirstUse ? '欢迎使用课程表' : '使用教程'),
            automaticallyImplyLeading: !isFirstUse),
        body: ListView(
            padding: const EdgeInsets.all(20),
            children: const <Widget>[
              _Lesson(
                  icon: Icons.school_outlined,
                  title: '1. 设置学期',
                  text: '选择实际开学日期和放假第一天。放假必须晚于开学，自动计算教学周，也可手动调整。以后可在设置中修改。'),
              _Lesson(
                  icon: Icons.add_box_outlined,
                  title: '2. 快捷添加课程',
                  text:
                      '点击课表空白格显示＋，再点＋进入添加页，星期和节次会自动填写。点击上课时段可修改；默认第1周到学期末、每周上课。'),
              _Lesson(
                  icon: Icons.calendar_view_week,
                  title: '3. 周课表与日课表',
                  text: '左上角切换周／日课表。周视图切换教学周，日视图选择日期或前后一天；两种视图共用同一份课程。'),
              _Lesson(
                  icon: Icons.palette_outlined,
                  title: '4. 颜色与时间',
                  text: '添加或编辑课程时可选14种颜色。课表左侧可修改节次时间，设置中可调整学期、主题和上课提醒。'),
              _Lesson(
                  icon: Icons.backup_outlined,
                  title: '5. 备份与更新',
                  text:
                      '数据保存在本机，卸载会删除。请将课程备份分享到应用外保存；主题与提醒偏好不包含在JSON备份里。更新前建议备份，安装由系统确认。'),
            ]),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                    onPressed: () {
                      if (isFirstUse) {
                        Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                                builder: (_) => const SemesterSettingsPage(
                                    isOnboarding: true)));
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(isFirstUse ? '下一步：设置学期' : '完成')))),
      );
}

class _Lesson extends StatelessWidget {
  const _Lesson({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: <Widget>[
                Icon(icon),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleMedium))
              ]),
              const SizedBox(height: 8),
              Text(text),
            ]),
      ));
}
