param([switch]$SkipBuild)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if (-not $SkipBuild) { & "$PSScriptRoot/build.ps1" }
$jar=Join-Path $root 'target/smart-expiry-server-0.4.0-local.jar'
if (-not (Test-Path -LiteralPath $jar)) { throw 'Build the backend JAR first.' }
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$release=Join-Path $root "target/cloud-$stamp-$([guid]::NewGuid().ToString('N').Substring(0,6))"
New-Item -ItemType Directory -Path "$release/target","$release/deploy" -Force | Out-Null
Copy-Item -LiteralPath $jar -Destination "$release/target/"
Copy-Item -LiteralPath "$root/Dockerfile" -Destination $release
Copy-Item -LiteralPath "$root/.dockerignore" -Destination $release
foreach($name in @('compose.cloud.yml','Caddyfile','.env.example','healthcheck.sh','check-db.sh','backup-db.sh','check-config.py')) {
    Copy-Item -LiteralPath "$root/deploy/$name" -Destination "$release/deploy/$name"
}
Copy-Item -LiteralPath "$root/docs/CLOUD_DEPLOYMENT.md" -Destination "$release/DEPLOYMENT.md"
@{createdAt=(Get-Date).ToUniversalTime().ToString('o');jarSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $jar).Hash} |
    ConvertTo-Json | Set-Content -LiteralPath "$release/release.json" -Encoding utf8
$archive="$release.tar.gz"
& tar -czf $archive -C $release .
if ($LASTEXITCODE -ne 0) { throw 'Release archive creation failed.' }
Write-Output "Cloud release package: $archive"
Write-Output 'Package excludes local database, .env, secrets and certificates.'
