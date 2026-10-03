param(
    [string]$DevEcoHome = 'D:/DevEco/DevEco Studio',
    [string]$JavaHome = $env:JAVA_HOME,
    [switch]$TestHap
)
$ErrorActionPreference = 'Stop'
if (-not $JavaHome) {
    $JavaHome = (Get-ChildItem 'C:/Program Files/Java' -Directory -Filter 'jdk-21*' | Sort-Object Name -Descending | Select-Object -First 1).FullName
}
if (-not (Test-Path "$JavaHome/bin/java.exe")) { throw 'Set JAVA_HOME to a JDK 21 installation.' }
if (-not (Test-Path "$DevEcoHome/tools/hvigor/bin/hvigorw.bat")) { throw 'Pass -DevEcoHome with your DevEco Studio directory.' }
$env:JAVA_HOME = $JavaHome
$env:DEVECO_SDK_HOME = "$DevEcoHome/sdk"
$env:PATH = "$JavaHome/bin;$DevEcoHome/tools/node;" + $env:PATH
Push-Location (Join-Path $PSScriptRoot '..')
try {
    & "$DevEcoHome/tools/ohpm/bin/ohpm.bat" install
    if ($LASTEXITCODE -ne 0) { throw 'ohpm install failed' }
    $target = if ($TestHap) { 'entry@ohosTest' } else { 'entry@default' }
    & "$DevEcoHome/tools/hvigor/bin/hvigorw.bat" --mode module -p product=default -p "module=$target" assembleHap --no-daemon
    if ($LASTEXITCODE -ne 0) { throw "Hvigor failed: $LASTEXITCODE" }
} finally { Pop-Location }
