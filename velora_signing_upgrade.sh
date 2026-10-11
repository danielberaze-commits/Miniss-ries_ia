#!/usr/bin/env bash
set -euo pipefail

# Execute after flutter create and before flutter build apk/appbundle.
# Secrets are supplied only by GitHub Actions environment variables.
: "${VELORA_KEYSTORE_BASE64:?Missing VELORA_KEYSTORE_BASE64 secret}"
: "${VELORA_KEYSTORE_PASSWORD:?Missing VELORA_KEYSTORE_PASSWORD secret}"
: "${VELORA_KEY_PASSWORD:?Missing VELORA_KEY_PASSWORD secret}"

python3 - <<'PY'
import base64, os, pathlib, re
raw = os.environ['VELORA_KEYSTORE_BASE64'].strip()
raw = re.sub(r'-----BEGIN [^-]+-----|-----END [^-]+-----|\s+', '', raw)
try:
    decoded = base64.b64decode(raw, validate=True)
except Exception as exc:
    raise SystemExit('Invalid Base64 keystore secret') from exc
if len(decoded) < 100:
    raise SystemExit('Keystore appears too small')
path = pathlib.Path('android/app/velora-upload.jks')
path.parent.mkdir(parents=True, exist_ok=True)
path.write_bytes(decoded)
PY

GRADLE_FILE=android/app/build.gradle.kts
if [[ ! -f "$GRADLE_FILE" ]]; then
  echo "Expected $GRADLE_FILE not found" >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
p = Path('android/app/build.gradle.kts')
s = p.read_text()
if 'VELORA_SIGNING_BEGIN' in s:
    raise SystemExit('Velora signing already configured')
if 'signingConfigs {' in s:
    raise SystemExit('Existing signingConfigs detected; inspect before modifying')
if 'signingConfig = signingConfigs.getByName("debug")' not in s:
    raise SystemExit('Expected Flutter debug signingConfig not found; inspect Gradle file')
# The Gradle Kotlin DSL can reference System.getenv without imports.
marker = '    buildTypes {'
if marker not in s:
    raise SystemExit('Expected buildTypes block not found')
config = '''    // VELORA_SIGNING_BEGIN
    signingConfigs {
        create("veloraRelease") {
            storeFile = file("velora-upload.jks")
            storePassword = System.getenv("VELORA_KEYSTORE_PASSWORD")
            keyAlias = "velora"
            keyPassword = System.getenv("VELORA_KEY_PASSWORD")
        }
    }
    // VELORA_SIGNING_END

'''
s = s.replace(marker, config + marker, 1)
s = s.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("veloraRelease")', 1)
p.write_text(s)
PY

echo 'Velora release signing configured.'
