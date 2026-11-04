param()
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    if (!(Test-Path android/key.properties)) { throw 'Configure android/key.properties first; see docs/RELEASE_1.1.md' }
    flutter analyze --no-pub
    if ($LASTEXITCODE) { throw 'Analysis failed' }
    flutter test --no-pub
    if ($LASTEXITCODE) { throw 'Tests failed' }
    flutter build apk --release --no-pub
    if ($LASTEXITCODE) { throw 'Release build failed' }
    Get-FileHash build/app/outputs/flutter-apk/app-release.apk -Algorithm SHA256
} finally { Pop-Location }
