#!/usr/bin/env bash
set -euo pipefail

VERSION_FILE="VERSION"
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "VERSION file is missing" >&2
  exit 1
fi
VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?\+[0-9]+$ ]]; then
  echo "Invalid version: $VERSION" >&2
  exit 1
fi
python3 - "$VERSION" <<'PY'
from pathlib import Path
import re, sys
v = sys.argv[1]
p = Path('pubspec.yaml')
s = p.read_text()
s, n = re.subn(r'(?m)^version:\s*.*$', f'version: {v}', s, count=1)
if n != 1: raise SystemExit('pubspec version line not found')
p.write_text(s)

p = Path('lib/core/app_version.dart')
p.write_text(f"/// Generated from VERSION. Do not edit manually.\nconst String appVersion = '{v}';\n")

p = Path('backend/wrangler.toml')
s = p.read_text()
s = re.sub(r'(?m)^APP_VERSION\s*=\s*"[^"]*"', f'APP_VERSION = "{v}"', s)
p.write_text(s)
PY
printf '%s\n' "$VERSION" > VERSION
echo "Synchronized version: $VERSION"
