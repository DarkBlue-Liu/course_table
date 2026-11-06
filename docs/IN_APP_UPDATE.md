> 当前1.3脚本、版本与验收步骤见 [1.3验收文档](RELEASE_1.3.md)。下文保留1.2的历史验收记录。

# 应用内更新：发布前检查与分阶段验收

## 发布前检查（2026-11-05）

现有正式版：applicationId=com.example.course_table，versionName=1.1.0，versionCode=2。
本次候选版：1.2.0+4。局域网验收包使用 versionCode=3；不得将其公开发布。
正式签名证书 SHA256：f5cc0623dda2a54a4fd16bf2bae9c6e1210a3ebbc44375414c94428df90a045c。
普通 Debug 使用开发签名，不能覆盖正式版。本项目不更换正式私钥。验收脚本先构建普通 Debug，再使用 apksigner 和正式 JKS 明确重签为私有验收包，随后验证实际证书；默认 Debug 签名不变。密码仅通过子进程环境传递，不输出或保存到脚本。

SQLite course_table.db 当前版本 2，保存 semester/time_slot/course/course_schedule；SharedPreferences 保存主题、提醒开关、提前时间和引导状态。本次不改变这些路径、键名或表结构，不执行清库。v1→v2 为新增字段迁移，拒绝降级。导入 JSON 会覆盖课程等数据，且多个事务中途失败尚无整体回滚；更新不自动执行导入。升级前建议在设置中导出并分享备份到应用外。

需保管：课程 JSON、另行记录主题/提醒偏好；正式 JKS；密码管理器中的密码；版本号、证书指纹和 APK SHA256。JSON 不含主题和提醒偏好。JKS/密码文件必须分开备份，当前同盘副本不是异地备份。密钥与密码文件在 Git 忽略规则内，禁止提交或放入文件服务目录。

手机旧签名核对（连接 USB 并允许调试）：
```powershell
E:\Android\SDK\platform-tools\adb.exe shell pm path com.example.course_table
# 把输出 package: 后的完整 base.apk 路径代入下一条
E:\Android\SDK\platform-tools\adb.exe pull /data/app/实际路径/base.apk build/phone-old.apk
$env:JAVA_HOME='E:\Android\Android studio\jbr'
E:\Android\SDK\build-tools\37.0.0\apksigner.bat verify --print-certs build/phone-old.apk
```
签名、包名均一致且 versionCode 递增才允许覆盖。本次原生安装桥再次检查包名、实际 APK 版本与当前证书完全一致，不实现证书轮换。手机已由使用者确认是正式版，实际 APK 指纹与完整真机流程仍待设备验收。

## 第一阶段：Windows 11 与同 Wi-Fi 手机

1. 项目根目录运行 `flutter pub get --offline`（首次依赖没有缓存时去掉 --offline）。
2. `powershell -ExecutionPolicy Bypass -File scripts/build-lan-acceptance.ps1` 生成 `build/lan-packages/course-table-lan-3.apk`。此 Debug 验收包使用正式签名，支持 HTTP，仅供自己验收。
3. 将验收包传到手机并选择更新，保持现有数据。也可 `adb install -r build/lan-packages/course-table-lan-3.apk`；不可先卸载。签名冲突立即停止。
4. 运行 `powershell -ExecutionPolicy Bypass -File scripts/build-release.ps1`，生成默认 1.2.0+4 正式候选包（HTTPS 更新入口暂为空）。
5. 电脑和手机连接同一 Wi-Fi，Windows 网络设为“专用”。运行 `ipconfig`，读取 Wi-Fi 网卡的 IPv4（不要选虚拟网卡）。
6. 本机已查得 Wi-Fi IPv4 为 192.168.18.51；下列示例中的 192.168.1.10 应替换为实际 IP。假设电脑 IP 为 192.168.1.10，运行：
```powershell
cd E:\Workspace\Projects\Android\course_table
powershell -ExecutionPolicy Bypass -File scripts/serve-update.ps1 -ComputerIP 192.168.1.10
```
脚本只公开 build/lan-update，使用 HTTP/1.1，自动复制 APK 并生成大小、SHA256 与绝对下载地址（需要 Python 3.11+；本机为 3.13）。在手机浏览器打开 http://实际电脑IP:8765/course-table-lan-3.apk 可先下载验收包；浏览器首次安装也需单独授权来源。不能从项目根目录直接运行文件服务器。Windows 防火墙弹窗仅允许专用网络；如果没有弹窗，可在管理员 PowerShell 添加：
```powershell
New-NetFirewallRule -DisplayName 'CourseTable LAN update test' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8765 -Profile Private -RemoteAddress LocalSubnet
# 测试完删除
Remove-NetFirewallRule -DisplayName 'CourseTable LAN update test'
```
7. 手机浏览器先访问 `http://192.168.1.10:8765/version.json`；可见 JSON 后，在验收包的“设置→版本与更新”填写同一地址，检查、下载、确认、安装。模拟器可用 10.0.2.2 代替电脑 IP，但它不等同于手机同 Wi-Fi 验收。
8. 首次会进入“允许此来源安装应用”设置，授权后返回，再点“安装更新”。系统安装器由用户确认，不能静默安装。系统提示取消时可返回原 App 继续使用，仍可再次安装。
9. 安装后版本应为 1.2.0(4)，线上尚未配置时提示信息，不允许 HTTP。Ctrl+C 停止服务器，移除临时防火墙规则。

若浏览器访问失败，依次检查：同一子网、Windows 专用网络防火墙、服务仍在运行、IP 未变化、路由器未开启客户端隔离/访客网络。不要通过关闭整个防火墙排查。

### 必须逐项验收

- 原 1.1 正式版→同签名 Debug(3)→正式候选(4)，均覆盖安装，不卸载。
- 更新前创建多课程/多时段、学期和节次设置，记录主题、提醒开关/提前时间；取消安装和最终升级后逐项比对。
- 下载中断 Wi-Fi：显示错误，恢复后重试；下载中取消：删除半成品，可重试。
- 损坏 sha256/size：拒绝安装；签名/包名/版本不一致：原生桥拒绝；不得改 APK 后再期望原校验值有效。
- 系统安装弹窗选择取消，检查课程仍可查看/编辑；之后再次点击安装成功。
- Release 明文策略同时由 Dart URL 检查和 Manifest 强制，正式包绝不使用局域网地址。

## 第二阶段：线上入口与托管条件

暂不购买、开通或部署服务。默认 UPDATE_MANIFEST_URL 为空，正常使用课程功能。准备好托管后按构建参数传入：
```powershell
flutter build apk --release --dart-define=UPDATE_MANIFEST_URL=https://downloads.example.com/course-table/version.json
```
检查入口在编译时配置；更换该入口需要重新发包，因此应选择自己长期控制的稳定入口。每次发布在 JSON 中替换 apkUrl 即可切换下载主机，无需修改 App。地址不是凭据，不应包含密钥或永久签名令牌。

版本文件 schemaVersion=1，字段为 applicationId、versionCode、versionName、apkUrl、size（字节）、sha256（64 位十六进制）、notes。以 Android versionCode 判断更新，不能比较版本名称字符串。APK实际包名/版本/证书须与清单和已安装包匹配；校验成功后通过只读 FileProvider URI 调用系统安装器。

托管必须具备：
- 大陆运营商 Wi-Fi/移动网络可访问的有效 HTTPS 证书，版本 JSON 与 APK（包括重定向链）均不得降级 HTTP。
- 匿名 GET 下载，不需要账号、Cookie、JS 验证、下载确认页面；返回真实 JSON 和 APK；允许至少 512 MB 范围内的 APK，设置准确 Content-Length 或支持分块传输。
- 版本文件小于 64 KiB，短缓存或 no-cache；APK 使用独立不可变版本路径，长缓存。先上传并核验 APK，再原子替换版本文件，避免 JSON 指向未上传完成的包。
- 具备合适带宽、流量额度、持久保存与可迁移 URL；对象存储、静态托管或 CDN 均可，不需要业务后端。
- 发布权限和域名/DNS 权限妥善保管，HTTPS与SHA256不能替代 APK 签名；签名密钥仍是更新身份的根。
- 未来公开发布前确认域名/托管地区相关要求、应用分发渠道规则、隐私说明与真机兼容性。当前方案面向自己和独立 APK 分发；若将来上 Google Play，应按其政策改用商店更新机制，不能直接套用此自更新权限。

下载失败从头重试，不实现断点/增量/热更新。更新器只访问版本文件与 APK，不上传课程。取消不会删除数据库；应用重启后可重新检查和下载。首次从没有更新器的 1.1 升级仍需手动安装一次。

## 验证记录

电脑、模拟器及用户反馈的真机验收结果分别记录如下；未明确确认的项目不视为已通过。

### 本轮电脑与模拟器结果（2026-11-05）

- 签名：最终 Debug 私有验收包与 Release 候选包均通过 apksigner 实物验证，与 1.1 正式证书完全一致；普通 Debug 默认仍为原开发证书。
- 正式候选版 1.2.0+4；验收版 1.2.0+3；Release Manifest usesCleartextTraffic=false，AOT 库中未发现 192.168.18.51/10.0.2.2 测试 IP。
- 更新服务通过 Windows 实际 Python 文件服务完整下载约 57 MB APK，并校验成功；多兆字节 HTTP 流式测试、取消、重试、损坏哈希、URL策略与重定向拒绝均通过。
- 专用 ReleaseTest 模拟器：原 1.1 正式版覆盖为 Debug(3) 成功；页面实际返回版本与正式证书；检查版本、下载校验、打开系统更新弹窗、取消后版本仍为3、再次确认安装至正式4全部通过。
- 本机 Python 默认 HTTP/1.0 模式在模拟器大文件下载时出现连接提前关闭；显式使用 HTTP/1.1 后完成全流程。服务脚本已经固定该选项；不能只用小 JSON 能访问来判断大文件下载可用。
- SQLite 更新前后逐行比对一致：semester=1、time_slot=10、course=1、course_schedule=1；user_version=2，integrity_check=ok。具体本机记录在 build/upgrade-verification/in-app-update-result.json，不提交测试数据库。
- 本轮模拟器沿用默认主题和提醒偏好，未独立覆盖所有非默认偏好组合；真机结果见下方用户反馈记录。
- 没有购买或开通托管，没有部署线上更新地址，也没有发布本候选版至 GitHub。线上入口的 HTTPS 可配置能力已实现，真实线上网络验收待托管地址可用后执行。

本机手机操作：先备份；同 Wi-Fi 浏览器打开 http://192.168.18.51:8765/course-table-lan-3.apk 覆盖安装验收包；应用内检查地址 http://192.168.18.51:8765/version.json 已在该验收包中预填（仅 Debug）；先做断网/取消/重试，最后安装正式候选。IP 变化后重新生成 JSON 和填写 Debug 地址即可，无需改正式版。
- 最终自动检查：flutter analyze --no-pub 零问题；flutter test --no-pub 全部 93 个测试通过。

Windows 网络补充：本轮查到 WLAN 当前是 Public（公用网络）。仅当这是您信任的家庭/个人 Wi-Fi 时，在 Windows 11“设置→网络和 Internet→WLAN→已连接网络属性→网络配置文件类型”改为“专用网络”，再按上文仅 Private/LocalSubnet 的防火墙规则放行 8765。不要为测试向公用网络开放服务。当前本机文件服务已启动；真机若访问失败，先处理这一项。手动测试完成可让我停止本次服务；自行启动的前台服务用 Ctrl+C 停止。

### 真机手动验收反馈（2026-11-05）

- 用户手机原安装正式版，经同正式签名的 Debug 验收包进行应用内更新，用户确认：“已更新到 1.2.0(4)，数据和设置正常”。据此记录真机覆盖更新、数据与设置保留通过；这是用户手动反馈，不是电脑提取手机数据库的结果。
- 实际网络为手机个人热点，电脑连接该热点；电脑地址为 192.168.122.99，手机访问 http://192.168.122.99:8765/version.json。没有将原公共 Wi-Fi 改成可信家庭网络。
- 曾因验收页面仍填旧地址 192.168.18.51 而超时；更换为热点地址后检查更新及后续安装成功。正式版仍只允许 HTTPS，不依赖上述测试地址。
- 真机取消系统安装、断网失败后重试尚未获得用户明确确认，继续保留为待验收；这些场景已有自动测试或模拟器验证，不替代真机结果。
- 第二阶段已预留 HTTPS 入口和可替换 apkUrl；尚未接入托管或完成公网 HTTPS 验收，未购买或开通云服务。
