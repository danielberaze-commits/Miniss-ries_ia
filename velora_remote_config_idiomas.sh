#!/usr/bin/env bash
set -euo pipefail
# Velora — mensagens remotas em pt-BR/en/es e atualização ao voltar ao aplicativo.
# Executar no mesmo ponto existente do build.yml: depois de
# velora_remote_config_etapa2.sh e velora_language_live_refresh.sh.
# Preserva a Home, o login, a navegacao e as configuracoes previamente carregadas
# durante a sessao se uma nova consulta ao Supabase falhar.
python3 - <<'PY'
from pathlib import Path
import re

p = Path('lib/screens/home_screen.dart')
if not p.is_file():
    raise SystemExit('ERRO: home_screen.dart ausente. Nenhuma alteracao realizada.')
s = p.read_text(encoding='utf-8')
original = s

required = (
    'VeloraRemoteConfig.home',
    'VeloraRemoteConfig.refresh()',
    'VeloraLanguageStore.current.value',
    'class HomeScreen',
    'class _HomeScreenState extends State<HomeScreen>',
    '  Widget _empty()',
)
for item in required:
    if item not in s:
        raise SystemExit(f'ERRO: estrutura necessaria ausente ({item}). Nenhuma alteracao realizada.')

# 1. Mantem a traducao das mensagens remotas ja aprovada pelo usuario.
helper_signature = 'String _veloraRemoteWelcomeMessage() {'
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
if helper_signature not in s:
    pattern = re.compile(
        r'''final remoteMessage\s*=\s*VeloraRemoteConfig\.home\['welcome_message'\];\s*final message\s*=\s*remoteMessage is String && remoteMessage\.trim\(\)\.isNotEmpty\s*\? remoteMessage\.trim\(\)\s*:\s*'O próximo capítulo começa aqui';'''
    )
    s, n = pattern.subn('final message = _veloraRemoteWelcomeMessage();', s, count=1)
    if n != 1 or s.count('class HomeScreen') != 1:
        raise SystemExit('ERRO: mensagem remota em formato inesperado. Nenhuma alteracao realizada.')
    s = s.replace('class HomeScreen', helper + 'class HomeScreen', 1)
else:
    if 'final message = _veloraRemoteWelcomeMessage();' not in s:
        raise SystemExit('ERRO: helper remoto existente mas nao conectado a Home. Nada alterado.')

# 2. Permite substituir o Future ao retornar do segundo plano.
old_future = '  late final Future<bool> _veloraRemoteHomeFuture = VeloraRemoteConfig.refresh();'
new_future = '  late Future<bool> _veloraRemoteHomeFuture = VeloraRemoteConfig.refresh();'
if old_future in s:
    s = s.replace(old_future, new_future, 1)
elif new_future not in s:
    raise SystemExit('ERRO: campo Future remoto nao identificado. Nenhuma alteracao realizada.')
if 'future: _veloraRemoteHomeFuture' not in s:
    raise SystemExit('ERRO: FutureBuilder remoto nao encontrado. Nenhuma alteracao realizada.')

# 3. Escuta apenas o retorno do app ao primeiro plano. Sem polling e sem
# recriar a raiz do Flutter, preservando login, menu e estado de navegacao.
old_class = 'class _HomeScreenState extends State<HomeScreen> {'
new_class = 'class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {'
if new_class not in s:
    if s.count(old_class) != 1:
        raise SystemExit('ERRO: classe de estado inesperada. Nenhuma alteracao realizada.')
    s = s.replace(old_class, new_class, 1)

add_observer = '    WidgetsBinding.instance.addObserver(this);'
if add_observer not in s:
    init_anchor = '    super.initState();'
    if s.count(init_anchor) != 1:
        raise SystemExit('ERRO: initState nao encontrado de forma segura. Nada alterado.')
    s = s.replace(init_anchor, init_anchor + '\n' + add_observer, 1)

remove_observer = '    WidgetsBinding.instance.removeObserver(this);'
if remove_observer not in s:
    match = re.search(r'(?s)(  @override\s+void dispose\(\) \{)(.*?)(\n    super\.dispose\(\);)', s)
    if not match:
        raise SystemExit('ERRO: dispose da Home nao localizado. Nada alterado.')
    s = s[:match.start(3)] + '\n' + remove_observer + s[match.start(3):]

callback_signature = 'void didChangeAppLifecycleState(AppLifecycleState state)'
if callback_signature not in s:
    marker = '  void _reload() {'
    if s.count(marker) != 1:
        raise SystemExit('ERRO: ponto de integracao do ciclo de vida nao encontrado. Nada alterado.')
    callback = '''  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {
        _veloraRemoteHomeFuture = VeloraRemoteConfig.refresh();
      });
    }
  }

'''
    s = s.replace(marker, callback + marker, 1)

if s.count('WidgetsBinding.instance.addObserver(this);') != 1 or s.count('WidgetsBinding.instance.removeObserver(this);') != 1:
    raise SystemExit('ERRO: observador de ciclo de vida duplicado. Nada alterado.')
if s.count('void didChangeAppLifecycleState(AppLifecycleState state)') != 1:
    raise SystemExit('ERRO: callback de ciclo de vida duplicado. Nada alterado.')
if 'VeloraRemoteConfig.home[key]' not in s or 'final message = _veloraRemoteWelcomeMessage();' not in s:
    raise SystemExit('ERRO: traducoes remotas nao preservadas. Nada alterado.')

if s != original:
    p.write_text(s, encoding='utf-8')
print('OK: mensagens remotas pt-BR/en/es preservadas.')
print('OK: consulta inicial e nova consulta ao retornar ao aplicativo.')
print('OK: nenhuma alteracao em rotas, login, navegacao ou sistema de atualizacao.')
print('NOTA: ao ficar offline, o servico existente mantem os dados carregados nesta sessao.')
PY
