#!/usr/bin/env bash
set -euo pipefail
# Executar apos velora_language_screen_upgrade.sh.
# Atualiza somente o titulo do seletor no Perfil quando o idioma mudar.
python3 - <<'PY'
from pathlib import Path
p = Path('lib/velora_language_selector.dart')
if not p.is_file():
    raise SystemExit('ERRO: seletor de idiomas nao encontrado.')
s = p.read_text(encoding='utf-8')
old = "title: Text(VeloraText.get('language'))," 
new = """title: ValueListenableBuilder<VeloraLanguage>(
        valueListenable: VeloraLanguageStore.current,
        builder: (context, language, child) =>
            Text(VeloraText.get('language', language)),
      ),"""
if new in s:
    print('OK: atualizacao reativa ja aplicada.')
elif s.count(old) == 1 and 'class VeloraLanguageSelector' in s:
    p.write_text(s.replace(old, new, 1), encoding='utf-8')
    print('OK: titulo Idioma/Language/Idioma atualizado imediatamente.')
else:
    raise SystemExit('ERRO: estrutura do seletor inesperada; arquivo preservado.')
PY
