param([string]$JavaHome = $env:JAVA_HOME, [string]$MavenRepo = (Join-Path $env:USERPROFILE '.m2/repository'))
$ErrorActionPreference = 'Stop'
if (-not $JavaHome) {
    $JavaHome = (Get-ChildItem 'C:/Program Files/Java' -Directory -Filter 'jdk-21*' | Sort-Object Name -Descending | Select-Object -First 1).FullName
}
if (-not (Test-Path "$JavaHome/bin/java.exe")) { throw 'Set JAVA_HOME to a JDK 21 installation.' }
$env:JAVA_HOME = $JavaHome
$env:PATH = "$JavaHome/bin;" + $env:PATH
Push-Location (Join-Path $PSScriptRoot '..')
try {
    & ./mvnw.cmd "-Dmaven.repo.local=$MavenRepo" verify
    if ($LASTEXITCODE -ne 0) { throw "Maven failed: $LASTEXITCODE" }
} finally { Pop-Location }
