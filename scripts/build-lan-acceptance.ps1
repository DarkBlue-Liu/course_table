param(
    [string]$ManifestUrl = '',
    [string]$JavaHome = 'E:\Android\Android studio\jbr'
)
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    if (!(Test-Path android/key.properties)) { throw 'Release signing configuration is required' }
    flutter build apk --debug --no-pub --build-number=3 --dart-define="UPDATE_MANIFEST_URL=$ManifestUrl"
    if ($LASTEXITCODE) { throw 'LAN acceptance build failed' }
    New-Item -ItemType Directory -Force build/lan-packages | Out-Null
    $signing = @{}
    foreach ($line in Get-Content android/key.properties) {
        if ($line -match '^([^#=]+)=(.*)$') { $signing[$matches[1].Trim()] = $matches[2] }
    }
    $sdkLine = Get-Content android/local.properties | Where-Object { $_.StartsWith('sdk.dir=') } | Select-Object -First 1
    $sdkRoot = $sdkLine.Substring(8).Replace('\\','\')
    $buildTools = Get-ChildItem (Join-Path $sdkRoot 'build-tools') -Directory | Sort-Object Name -Descending | Select-Object -First 1
    $signerJar = Join-Path $buildTools.FullName 'lib/apksigner.jar'
    $javaExe = Join-Path $JavaHome 'bin/java.exe'
    $keystore = [IO.Path]::GetFullPath((Join-Path (Join-Path $PWD 'android') $signing['storeFile']))
    $env:COURSE_TABLE_STORE_PASSWORD = $signing['storePassword']
    $env:COURSE_TABLE_KEY_PASSWORD = $signing['keyPassword']
    & $javaExe -jar $signerJar sign --ks $keystore --ks-key-alias $signing['keyAlias'] --ks-pass env:COURSE_TABLE_STORE_PASSWORD --key-pass env:COURSE_TABLE_KEY_PASSWORD --out build/lan-packages/course-table-lan-3.apk build/app/outputs/flutter-apk/app-debug.apk
    if ($LASTEXITCODE) { throw 'Release re-signing failed' }
    & $javaExe -jar $signerJar verify --print-certs build/lan-packages/course-table-lan-3.apk
    if ($LASTEXITCODE) { throw 'Signed APK verification failed' }
    Write-Host 'This Debug APK uses the Release key. Private testing only; do not publicly release it.'
} finally {
    $env:COURSE_TABLE_STORE_PASSWORD = $null
    $env:COURSE_TABLE_KEY_PASSWORD = $null
    $signing = $null
    Pop-Location
}
