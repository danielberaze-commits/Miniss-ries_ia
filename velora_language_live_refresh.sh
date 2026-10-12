#!/usr/bin/env bash
set -euo pipefail
# Execute depois de todos os scripts que alteram a Home e antes do flutter build.
python3 - <<'PY'
from pathlib import Path
import re
main = Path('lib/main.dart')
home = Path('lib/screens/home_screen.dart')
if not main.exists() or not home.exists():
    raise SystemExit('ERRO: main.dart ou home_screen.dart ausente.')
m = main.read_text(encoding='utf-8')
h = home.read_text(encoding='utf-8')
old = 'MiniSeriesApp(key: ValueKey(language.code))'
if old in m:
    m = m.replace(old, 'const MiniSeriesApp()', 1)
elif 'MiniSeriesApp(key: ValueKey(language.code))' not in m and 'builder: (context, language, child) => const MiniSeriesApp()' not in m:
    raise SystemExit('ERRO: inicializacao de idiomas inesperada em main.dart; arquivos preservados.')
if 'VeloraLanguageStore.current.addListener(_onVeloraLanguageChanged);' not in h:
    if 'VeloraLanguageStore' not in h:
        raise SystemExit('ERRO: integracao de idiomas ausente da Home; arquivos preservados.')
    anchor = '    super.initState();'
    if h.count(anchor) != 1:
        raise SystemExit('ERRO: initState da Home nao identificado com seguranca; arquivos preservados.')
    h = h.replace(anchor, anchor + '\n    VeloraLanguageStore.current.addListener(_onVeloraLanguageChanged);', 1)
    marker = '  void _reload() {'
    if h.count(marker) != 1:
        raise SystemExit('ERRO: _reload nao identificado; arquivos preservados.')
    extra = '''  void _onVeloraLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    VeloraLanguageStore.current.removeListener(_onVeloraLanguageChanged);
    super.dispose();
  }

'''
    h = h.replace(marker, extra + marker, 1)
main.write_text(m, encoding='utf-8')
home.write_text(h, encoding='utf-8')
print('OK: Home atualiza textos ao trocar idioma, sem recriar a raiz por chave.')
print('NOTA: AuthScreen ainda precisa de traducao em etapa separada.')
PY
