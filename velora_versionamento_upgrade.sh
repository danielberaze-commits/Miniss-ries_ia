#!/usr/bin/env bash
set -euo pipefail

# Velora: controla a versao do app sem alterar telas ou autenticacao.
# Executar apos setup.sh e antes de flutter build.

if [[ ! -f pubspec.yaml ]]; then
  echo 'Erro: pubspec.yaml nao encontrado. Execute apos setup.sh.' >&2
  exit 1
fi

APP_VERSION="${VELORA_APP_VERSION:-1.0.0}"
RUN_NUMBER="${GITHUB_RUN_NUMBER:-}"

if [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'Erro: VELORA_APP_VERSION deve ser X.Y.Z (ex.: 1.0.0).' >&2
  exit 1
fi

if [[ -z "$RUN_NUMBER" || ! "$RUN_NUMBER" =~ ^[0-9]+$ ]]; then
  echo 'Erro: GITHUB_RUN_NUMBER ausente ou invalido.' >&2
  exit 1
fi

# Offset para nao reutilizar o build number 1 do APK ja publicado.
BUILD_NUMBER=$((10000 + 10#$RUN_NUMBER))
if (( BUILD_NUMBER > 2100000000 )); then
  echo 'Erro: build number excedeu o limite seguro.' >&2
  exit 1
fi

python3 - "$APP_VERSION" "$BUILD_NUMBER" <<'PY'
from pathlib import Path
import re
import sys

version, build = sys.argv[1:]
path = Path('pubspec.yaml')
content = path.read_text(encoding='utf-8')
content, count = re.subn(
    r'(?m)^version:\s*[^\r\n]+$',
    f'version: {version}+{build}',
    content,
)
if count != 1:
    raise SystemExit('Erro: esperado exatamente um campo version: no pubspec.yaml')
path.write_text(content, encoding='utf-8')
print(f'Velora configurado: {version}+{build}')
PY
