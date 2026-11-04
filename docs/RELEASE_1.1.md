# 1.1 正式构建与升级

版本唯一来源是 pubspec.yaml：1.1.0+2。Android versionName 为 1.1.0，versionCode 为 2。每次对外发布（包括修订包）必须递增 + 后的整数；语义版本使用 主版本.次版本.修订版本。数据库版本独立，目前仍为 2。

运行 `flutter pub get` 后，在项目根目录执行 `powershell -File scripts/build-release.ps1`。产物为 build/app/outputs/flutter-apk/app-release.apk。缺少正式签名配置时 Release 构建必须失败，不允许回退至 Debug 签名。

## 签名与备份

本机私钥：signing-private/course-table-release.jks；别名 course-table。配置和密码在 android/key.properties。两者均忽略 Git，已限制当前 Windows 用户访问。signing-private/backup/course-table-release.jks 为同盘副本，SHA256 已与原件核对；这不构成异地灾备。

请把 JKS 副本复制到加密的离线介质或安全文件库，把 key.properties 中的密码另存至密码管理器。不要把明文配置与密钥一起上传或打包。恢复时保留相同别名和密码；storeFile 路径相对于 android 目录。不可丢失或随意重新生成正式私钥，否则已安装正式版无法继续覆盖升级。

新机器配置示例：

```properties
storeFile=../signing-private/course-table-release.jks
storePassword=<从密码管理器读取>
keyAlias=course-table
keyPassword=<从密码管理器读取>
```

## 旧版迁移限制

1.0 使用 Debug 签名。独立 Release 签名无法覆盖旧 Debug 包，不能通过更改 versionCode 解决。必须在旧版设置中导出 JSON 并分享到应用外，确认备份可用后，由用户卸载旧版、安装正式版并导入。JSON 不包含主题和提醒偏好。不得为测试擅自卸载用户已有应用。

同正式签名后续更新可用 `adb install -r 新版.apk` 或手机安装器覆盖安装，保留本地 SQLite 和偏好。包名保持 com.example.course_table。SQLite 文件保持 course_table.db，数据库版本为 2；数据库降级现在拒绝打开，不再自动删除数据。

## 验收要求

在独立测试设备安装正式签名基线，创建学期、课程与时段，保存数据库快照；覆盖安装 versionCode 更高且证书相同的 APK，再检查所有表内容、数据库版本、课程显示与偏好。签名不一致时应拒绝安装并保留旧数据。Release 禁用 run-as，直接读取其数据库应仅在可 root 的测试模拟器中进行。测试包不可作为正式基线发布。

## 2026-11-04 已执行验证

- `flutter analyze --no-pub`：零问题；`flutter test --no-pub`：84 个测试通过，含 v1 → v2 迁移、备份兼容和拒绝降级保留数据。
- Release APK 构建成功，包名 com.example.course_table，versionName=1.1.0，versionCode=2。
- `apksigner verify --print-certs` 通过，正式证书 SHA256：f5cc0623dda2a54a4fd16bf2bae9c6e1210a3ebbc44375414c94428df90a045c。
- 在专用 ReleaseTest 模拟器（emulator-5556）使用同一证书构建的 1.0.0+1 测试基线覆盖至 1.1.0+2；这不是历史 Debug APK。
- 更新前后四表逐行一致：semester 1、time_slot 10、course 1、course_schedule 1；数据库版本 2、integrity_check=ok。脚本为 scripts/verify-upgrade.py；本机明细在 build/upgrade-verification/result.json（忽略 Git）。
- 私钥备份与原件 SHA256 一致，且备份能使用保存的密码打开；异地备份尚需用户转存。

这些结果是模拟器验证，不代替通知送达等完整真机验收。
- 签名冲突检查：原 Debug APK 覆盖测试正式版被系统拒绝（INSTALL_FAILED_UPDATE_INCOMPATIBLE），拒绝前后数据库 SHA256 完全一致。
