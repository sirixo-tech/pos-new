[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [string]$IsccPath
)

$ErrorActionPreference = 'Stop'
$appRoot = Split-Path $PSScriptRoot -Parent
$pubspec = Get-Content (Join-Path $appRoot 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') {
    throw 'pubspec.yaml must specify version: major.minor.patch+build'
}
$appVersion = $Matches[1]
$appBuild = $Matches[2]

if (-not $IsccPath) {
    $compiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($compiler) { $IsccPath = $compiler.Source }
    foreach ($baseDir in @(${env:ProgramFiles(x86)}, $env:ProgramFiles, $env:LOCALAPPDATA)) {
        if ($IsccPath -or -not $baseDir) { continue }
        $candidate = Join-Path $baseDir 'Inno Setup 6\ISCC.exe'
        if (Test-Path -LiteralPath $candidate) { $IsccPath = $candidate }
    }
}
if (-not $IsccPath -or -not (Test-Path -LiteralPath $IsccPath)) {
    throw 'Install Inno Setup 6.3 or newer, or supply -IsccPath to ISCC.exe.'
}

Push-Location $appRoot
try {
    if (-not $SkipBuild) {
        & flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
        & flutter build windows --release "--build-name=$appVersion" "--build-number=$appBuild"
        if ($LASTEXITCODE -ne 0) { throw 'Windows release build failed' }
    }
    $releaseDir = Join-Path $appRoot 'build\windows\x64\runner\Release'
    foreach ($required in @('selfx_pos.exe', 'flutter_windows.dll', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'data\icudtl.dat', 'data\app.so', 'data\flutter_assets')) {
        if (-not (Test-Path -LiteralPath (Join-Path $releaseDir $required))) {
            throw "Release bundle is incomplete: $required. Run without -SkipBuild."
        }
    }
    $versionInfo = (Get-Item -LiteralPath (Join-Path $releaseDir 'selfx_pos.exe')).VersionInfo
    $builtVersion = '{0}.{1}.{2}.{3}' -f $versionInfo.FileMajorPart, $versionInfo.FileMinorPart, $versionInfo.FileBuildPart, $versionInfo.FilePrivatePart
    if ($builtVersion -ne "$appVersion.$appBuild") {
        throw "Release version $builtVersion does not match $appVersion.$appBuild. Run without -SkipBuild."
    }
    & $IsccPath "/DAppVersion=$appVersion" "/DAppBuild=$appBuild" 'windows\installer\selfx-pos.iss'
    if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed' }
    $installer = Join-Path $appRoot "build\installer\SELFX-POS-$appVersion+$appBuild-windows-setup.exe"
    $hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $(Split-Path $installer -Leaf)" | Set-Content -LiteralPath "$installer.sha256" -Encoding ascii
    Write-Host "Installer: $installer"
} finally {
    Pop-Location
}
