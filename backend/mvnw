#!/usr/bin/env sh
set -eu
BASE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MAVEN_VERSION=3.9.16
CACHE_DIR="$BASE_DIR/.mvn/wrapper/dists/apache-maven-$MAVEN_VERSION"
MVN="$CACHE_DIR/bin/mvn"
if [ ! -x "$MVN" ]; then
  mkdir -p "$BASE_DIR/.mvn/wrapper/dists"
  ZIP="$BASE_DIR/.mvn/wrapper/dists/apache-maven-$MAVEN_VERSION-bin.zip"
  URL="https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/$MAVEN_VERSION/apache-maven-$MAVEN_VERSION-bin.zip"
  echo "Downloading Maven $MAVEN_VERSION ..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$URL" -o "$ZIP"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$URL" -O "$ZIP"
  else
    echo "curl or wget is required for first Maven wrapper run" >&2
    exit 1
  fi
  python3 - "$ZIP" "$BASE_DIR/.mvn/wrapper/dists" <<'PY2'
import sys, zipfile
zip_path, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_path) as z:
    z.extractall(out)
PY2
  rm -f "$ZIP"
fi
exec "$MVN" "$@"
