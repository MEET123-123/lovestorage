param(
    [ValidateSet('local', 'default')][string]$Profile = 'local',
    [int]$Port = 8080,
    [switch]$LocalSms,
    [string]$JavaHome = $env:JAVA_HOME
)
$ErrorActionPreference = 'Stop'
if (-not $JavaHome) {
    $JavaHome = (Get-ChildItem 'C:/Program Files/Java' -Directory -Filter 'jdk-21*' | Sort-Object Name -Descending | Select-Object -First 1).FullName
}
if (-not (Test-Path "$JavaHome/bin/java.exe")) { throw 'Set JAVA_HOME to a JDK 21 installation.' }
Push-Location (Join-Path $PSScriptRoot '..')
try {
    $jar = 'target/smart-expiry-server-0.4.0-local.jar'
    if (-not (Test-Path $jar)) { throw 'Run scripts/build.ps1 first.' }
    $profiles = if ($LocalSms) { "$Profile,local-sms" } else { $Profile }
    if ($LocalSms) { Write-Host 'LOCAL SMS DEBUG: codes are returned to the client; no SMS is sent. Local testing only.' }
    & "$JavaHome/bin/java.exe" -jar $jar "--spring.profiles.active=$profiles" "--server.port=$Port"
    if ($LASTEXITCODE -ne 0) { throw "Server exited: $LASTEXITCODE" }
} finally { Pop-Location }
