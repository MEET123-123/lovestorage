@echo off
setlocal
set BASE_DIR=%~dp0
set MAVEN_VERSION=3.9.16
set CACHE_DIR=%BASE_DIR%.mvn\wrapper\dists\apache-maven-%MAVEN_VERSION%
set MVN=%CACHE_DIR%\bin\mvn.cmd
if exist "%MVN%" goto run
if not exist "%BASE_DIR%.mvn\wrapper\dists" mkdir "%BASE_DIR%.mvn\wrapper\dists"
set ZIP=%BASE_DIR%.mvn\wrapper\dists\apache-maven-%MAVEN_VERSION%-bin.zip
set URL=https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/%MAVEN_VERSION%/apache-maven-%MAVEN_VERSION%-bin.zip
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing '%URL%' -OutFile '%ZIP%'"
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%ZIP%' -DestinationPath '%BASE_DIR%.mvn\wrapper\dists' -Force"
del "%ZIP%"
:run
call "%MVN%" %*
