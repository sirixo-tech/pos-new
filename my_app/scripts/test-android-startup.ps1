param(
    [Parameter(Mandatory = $true)][string]$ApkPath,
    [Parameter(Mandatory = $true)][string]$DeviceId,
    [string]$AdbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
)

$ErrorActionPreference = 'Stop'
$package = 'in.selfx.pos'
function Invoke-Adb([string[]]$Arguments) {
    # Windows PowerShell turns successful adb progress on stderr into errors.
    $ErrorActionPreference = 'Continue'
    $output = & $AdbPath -s $DeviceId @Arguments 2>&1
    $adbExitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($adbExitCode -ne 0) { throw "adb failed ($adbExitCode): $($output -join "`n")" }
    return $output | ForEach-Object { $_.ToString() }
}

Invoke-Adb @('install', '--no-streaming', '-r', (Resolve-Path -LiteralPath $ApkPath).Path)
foreach ($attempt in 1..3) {
    Invoke-Adb @('shell', 'am', 'force-stop', $package) | Out-Null
    Invoke-Adb @('shell', 'am', 'start', '-W', '-n', "$package/.MainActivity")
    Start-Sleep -Seconds 10
    try {
        $appPid = Invoke-Adb @('shell', 'pidof', $package)
    } catch {
        throw "App exited after launch $attempt. Inspect: adb -s $DeviceId logcat -d -b crash"
    }
    if (-not ($appPid -join '').Trim()) { throw "App exited after launch $attempt" }
    $activities = Invoke-Adb @('shell', 'dumpsys', 'activity', 'activities')
    if (-not ($activities | Select-String "(?:mResumedActivity|topResumedActivity).*in\.selfx\.pos/")) {
        throw "POS is not the resumed Activity after launch $attempt"
    }
    Write-Output "PASS launch $attempt; process $appPid remains in foreground"
}
