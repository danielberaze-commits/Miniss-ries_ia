#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
import re
p = Path('lib/screens/home_screen.dart')
if not p.exists():
    raise SystemExit('ERRO: home_screen.dart ausente.')
s = p.read_text(encoding='utf-8')
if 'VeloraRemoteConfig.home' not in s or 'VeloraLanguageStore.current.value' not in s:
    raise SystemExit('ERRO: configuracao remota ou modulo de idiomas nao identificado. Nenhuma alteracao realizada.')
if '_veloraRemoteWelcomeMessage()' in s:
    print('OK: integracao de idiomas ja instalada.')
    raise SystemExit(0)
# Add a top-level helper before HomeScreen, beside existing _veloraTr helper.
anchor = 'class HomeScreen'
if s.count(anchor) != 1:
    raise SystemExit('ERRO: classe HomeScreen nao identificada com seguranca.')
helper = '''String _veloraRemoteWelcomeMessage() {
  String key;
  String fallback;
  switch (VeloraLanguageStore.current.value) {
    case VeloraLanguage.ptBR:
      key = 'welcome_message_pt';
      fallback = 'Bem-vindo ao Velora! Seu universo de histórias começa aqui.';
      break;
    case VeloraLanguage.en:
      key = 'welcome_message_en';
      fallback = 'Welcome to Velora! Your world of stories starts here.';
      break;
    case VeloraLanguage.es:
      key = 'welcome_message_es';
      fallback = '¡Bienvenido a Velora! Tu universo de historias comienza aquí.';
      break;
  }
  final value = VeloraRemoteConfig.home[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
}

'''
# Avoid changing unrelated welcome_message lookups: require exact expression in remote FutureBuilder.
pattern = re.compile(r'''final remoteMessage\s*=\s*VeloraRemoteConfig\.home\['welcome_message'\];\s*final message\s*=\s*remoteMessage is String && remoteMessage\.trim\(\)\.isNotEmpty\s*\? remoteMessage\.trim\(\)\s*:\s*'O próximo capítulo começa aqui';''')
new, n = pattern.subn('final message = _veloraRemoteWelcomeMessage();', s, count=1)
if n != 1:
    raise SystemExit('ERRO: bloco de boas-vindas remoto diferente do esperado. Nenhuma alteracao realizada.')
new = new.replace(anchor, helper + anchor, 1)
p.write_text(new, encoding='utf-8')
print('OK: mensagem remota da Home agora acompanha idioma ptBR/en/es.')
PY
