#!/usr/bin/env bash
set -euo pipefail
# Velora — idiomas remotos, atualizacao ao retomar e modo manutencao remoto.
# Substitui o script existente, no MESMO ponto do build.yml.
# Requer etapas remotas 1/2, integracao de idiomas e Home de acessibilidade.
# Nenhuma alteracao no Supabase e nenhuma mudanca de rotas/login.
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
        raise SystemExit(f'ERRO: estrutura necessaria ausente ({item}). Nada alterado.')

# 1. Traducao de boas-vindas remotas — preserva o comportamento aprovado.
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
        raise SystemExit('ERRO: boas-vindas em formato inesperado. Nada alterado.')
    s = s.replace('class HomeScreen', helper + 'class HomeScreen', 1)
elif 'final message = _veloraRemoteWelcomeMessage();' not in s:
    raise SystemExit('ERRO: helper remoto nao conectado a Home. Nada alterado.')

# 2. Future renovavel ao retornar do segundo plano — preserva o cache em memoria.
old_future = '  late final Future<bool> _veloraRemoteHomeFuture = VeloraRemoteConfig.refresh();'
new_future = '  late Future<bool> _veloraRemoteHomeFuture = VeloraRemoteConfig.refresh();'
if old_future in s:
    s = s.replace(old_future, new_future, 1)
elif new_future not in s:
    raise SystemExit('ERRO: Future remoto nao encontrado. Nada alterado.')
if 'future: _veloraRemoteHomeFuture' not in s:
    raise SystemExit('ERRO: FutureBuilder remoto ausente. Nada alterado.')

old_class = 'class _HomeScreenState extends State<HomeScreen> {'
new_class = 'class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {'
if new_class not in s:
    if s.count(old_class) != 1:
        raise SystemExit('ERRO: classe Home inesperada. Nada alterado.')
    s = s.replace(old_class, new_class, 1)

add_observer = '    WidgetsBinding.instance.addObserver(this);'
if add_observer not in s:
    anchor = '    super.initState();'
    if s.count(anchor) != 1:
        raise SystemExit('ERRO: initState nao localizado. Nada alterado.')
    s = s.replace(anchor, anchor + '\n' + add_observer, 1)
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

# 3. Modo manutencao — ler maintenance.enabled do mesmo cache remoto.
# O FutureBuilder externo redesenha a Home quando a consulta termina,
# inclusive na abertura e no retorno do segundo plano.
maintenance_method = '  Widget _veloraMaintenanceView() {'
maintenance_view = '''  Widget _veloraMaintenanceView() {
    final settings = VeloraRemoteConfig.maintenance;
    final language = VeloraLanguageStore.current.value;
    final String languageCode = switch (language) {
      VeloraLanguage.ptBR => 'pt',
      VeloraLanguage.en => 'en',
      VeloraLanguage.es => 'es',
    };
    final localized = settings['message_$languageCode'];
    final legacy = language == VeloraLanguage.ptBR ? settings['message'] : null;
    final configured = localized is String && localized.trim().isNotEmpty
        ? localized
        : legacy;
    final message = configured is String && configured.trim().isNotEmpty
        ? configured.trim()
        : _veloraTr(
            'Estamos preparando novidades para você.',
            'We are preparing something new for you.',
            'Estamos preparando novedades para ti.',
          );

    return Scaffold(
      backgroundColor: const Color(0xFF08070E),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'VELORA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFEBC58C),
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 5,
                          ),
                        ),
                        const SizedBox(height: 42),
                        const Icon(Icons.build_circle_outlined,
                            color: Color(0xFFEBC58C), size: 64),
                        const SizedBox(height: 18),
                        Text(
                          _veloraTr('Em manutenção', 'Under maintenance',
                              'En mantenimiento'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFFBDB5C9),
                          ),
                        ),
                        const SizedBox(height: 28),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _veloraRemoteHomeFuture =
                                  VeloraRemoteConfig.refresh();
                            });
                          },
                          icon: const Icon(Icons.refresh,
                              color: Color(0xFF8B2BEE)),
                          label: Text(_veloraTr('Verificar novamente',
                              'Check again', 'Comprobar de nuevo')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

'''
if maintenance_method not in s:
    marker = '  Widget _empty()'
    if s.count(marker) != 1:
        raise SystemExit('ERRO: _empty nao identificado. Nada alterado.')
    s = s.replace(marker, maintenance_view + marker, 1)

# 4. Mantem integralmente o build original num metodo auxiliar,
# envolvendo-o com um FutureBuilder para detectar maintenance.enabled.
# Nao substitui a arvore Scaffold original, nem callbacks ou rotas.
wrapper_signature = '  Widget _veloraStandardHome(BuildContext context) {'
if wrapper_signature not in s:
    state_pos = s.find(new_class)
    build_header = '  Widget build(BuildContext context) {'
    build_pos = s.find(build_header, state_pos)
    if state_pos < 0 or build_pos < 0 or s.count(build_header) != 1:
        raise SystemExit('ERRO: build da Home nao identificado com seguranca. Nada alterado.')
    wrapper = '''  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _veloraRemoteHomeFuture,
      builder: (context, snapshot) {
        if (VeloraRemoteConfig.maintenance['enabled'] == true) {
          return _veloraMaintenanceView();
        }
        return _veloraStandardHome(context);
      },
    );
  }

  Widget _veloraStandardHome(BuildContext context) {'''
    s = s[:build_pos] + s[build_pos:].replace(build_header, wrapper, 1)
else:
    if "VeloraRemoteConfig.maintenance['enabled'] == true" not in s:
        raise SystemExit('ERRO: manutencao parcialmente instalada. Nada alterado.')

# Valida consistencia antes de gravar.
for token in (
    'VeloraRemoteConfig.maintenance',
    'future: _veloraRemoteHomeFuture',
    '_veloraRemoteWelcomeMessage()',
    'final message = _veloraRemoteWelcomeMessage();',
    'setState(_reload)',
    'WidgetsBinding.instance.addObserver(this);',
    'WidgetsBinding.instance.removeObserver(this);',
    'void didChangeAppLifecycleState(AppLifecycleState state)',
    '  Widget _veloraMaintenanceView() {',
    '  Widget _veloraStandardHome(BuildContext context) {',
):
    if token not in s:
        raise SystemExit(f'ERRO: verificacao falhou ({token}). Nada alterado.')
if s.count("VeloraRemoteConfig.maintenance['enabled'] == true") != 1:
    raise SystemExit('ERRO: verificacao de manutencao duplicada. Nada alterado.')
if s != original:
    p.write_text(s, encoding='utf-8')
print('OK: boas-vindas remotas pt-BR/en/es preservadas.')
print('OK: atualizacao inicial e ao retornar do segundo plano preservada.')
print('OK: modo manutencao remoto no cache, com consulta de retorno e botao de revalidacao.')
print('OK: Home original, rotas, login e callbacks preservados.')
PY
