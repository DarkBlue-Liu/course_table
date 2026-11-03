# 1.0 上传与发布清单

## 源码上传 GitHub

- [x] README 总结 1.0 功能、使用方式、开发环境、数据库升级与已知限制。
- [x] 提交 pubspec.lock 以固定应用依赖；保留 Gradle Wrapper 脚本和 JAR。
- [x] 排除构建目录、本机 SDK 配置、IDE 状态、日志、数据库及签名密钥。
- [x] 将用于展示的模拟器截图复制到 docs/images，避免引用 build 临时目录。
- [x] 确定 GitHub 仓库地址：DarkBlue-Liu/course_table（上传前远程尚无分支）。
- [ ] 确定源码许可证；不要在未选择授权方式时宣称已采用某个开源许可证。
- [ ] 审阅首次提交文件清单，创建本地提交并推送。

在工程根目录操作，远程仓库为 DarkBlue-Liu/course_table：

```sh
git status --short
git add .
git diff --cached --stat
git diff --cached --check
git commit -m "Prepare course timetable 1.0 source"
git remote add origin https://github.com/DarkBlue-Liu/course_table.git
git push -u origin main
```

若已有 origin，先检查 `git remote -v`，不要重复添加或覆盖已有地址。首次提交需要配置自己的 Git 姓名和邮箱。

## Android 正式分发

- [ ] 完整真机流程：课程增删改、多时段、单双周、冲突确认与并排显示、周次导航、主题和节次修改。
- [ ] 通知权限允许 / 拒绝、实际定时送达、设备重启、后台及省电策略下的行为。
- [ ] 备份分享至应用外部、卸载重装后的覆盖恢复。
- [ ] 确认正式 applicationId、应用名称和图标。
- [ ] 将 android/app/build.gradle.kts 的 release Debug 签名替换为独立发布签名。
- [ ] 安全保管签名密钥与密码；不提交 key.properties、JKS 或 keystore。
- [ ] 执行 flutter analyze、flutter test 和正式签名构建。

完成签名配置后可构建：

```sh
flutter build apk --release --split-per-abi
```

当前尚未执行正式签名发布，不应将现有 Debug 包标注为已验收的稳定正式版。
