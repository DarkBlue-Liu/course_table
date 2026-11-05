param(
    [Parameter(Mandatory=$true)][string]$ComputerIP,
    [string]$Apk = 'build/app/outputs/flutter-apk/app-release.apk',
    [int]$VersionCode = 4,
    [string]$VersionName = '1.2.0',
    [int]$Port = 8765
)
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    $parsedIP = [Net.IPAddress]::Parse($ComputerIP)
    if ($parsedIP.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw 'Use the Wi-Fi IPv4 address' }
    New-Item -ItemType Directory -Force build/lan-update | Out-Null
    Copy-Item -LiteralPath $Apk -Destination build/lan-update/course-table.apk
    if (Test-Path build/lan-packages/course-table-lan-3.apk) {
        Copy-Item build/lan-packages/course-table-lan-3.apk build/lan-update/course-table-lan-3.apk
        Write-Host "Phone bootstrap APK: http://${ComputerIP}:${Port}/course-table-lan-3.apk"
    }
    $apkFile = Get-Item build/lan-update/course-table.apk
    $manifest = [ordered]@{
        schemaVersion = 1; applicationId = 'com.example.course_table';
        versionCode = $VersionCode; versionName = $VersionName;
        apkUrl = "http://${ComputerIP}:${Port}/course-table.apk";
        size = $apkFile.Length; sha256 = (Get-FileHash $apkFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant();
        notes = '局域网更新验收：验证覆盖安装、课程和设置保留、下载重试及取消安装。'
    }
    [IO.File]::WriteAllText((Join-Path $PWD 'build/lan-update/version.json'), ($manifest | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    Write-Host "Phone manifest URL: http://${ComputerIP}:${Port}/version.json"
    Write-Host 'Only build/lan-update is served. Stop with Ctrl+C. Never serve the project root.'
    python -m http.server $Port --protocol HTTP/1.1 --bind 0.0.0.0 --directory build/lan-update
} finally { Pop-Location }
