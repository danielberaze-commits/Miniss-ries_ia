#!/usr/bin/env bash
set -euo pipefail

# Velora - atualizacoes via public.app_versions.
# Execute depois dos scripts que geram/alteram lib/main.dart e antes de flutter pub get.
if [[ ! -f pubspec.yaml || ! -f lib/main.dart ]]; then
  echo 'Erro: execute na raiz do projeto Flutter.' >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
p=Path('pubspec.yaml')
s=p.read_text(encoding='utf-8')
if 'dependencies:\n' not in s:
    raise SystemExit('Secao dependencies nao encontrada')
for name, version in [('package_info_plus','^8.0.0'),('url_launcher','^6.3.0')]:
    import re
    if not re.search(r'^\s*'+name+r'\s*:',s,re.M):
        s=s.replace('dependencies:\n',f'dependencies:\n  {name}: {version}\n',1)
p.write_text(s,encoding='utf-8')
PY

mkdir -p lib/services
cat > lib/services/velora_update_gate.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class VeloraUpdateGate extends StatefulWidget {
  const VeloraUpdateGate({super.key, required this.child, required this.navigatorKey});
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<VeloraUpdateGate> createState() => _VeloraUpdateGateState();
}

class _VeloraUpdateGateState extends State<VeloraUpdateGate>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _dialogOpen = false;
  String? _dismissedVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  List<int> _parts(String value) {
    final base = value.trim().split('+').first.split('-').first;
    return base.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  }

  bool _newer(String remote, String installed) {
    final a = _parts(remote);
    final b = _parts(installed);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  Future<void> _check() async {
    if (!mounted || _checking || _dialogOpen) return;
    _checking = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final row = await Supabase.instance.client
          .from('app_versions')
          .select('latest_version, minimum_version, update_url, update_message, force_update')
          .eq('platform', 'android')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (!mounted || row == null) return;
      final latest = (row['latest_version'] ?? '').toString().trim();
      final minimum = (row['minimum_version'] ?? '').toString().trim();
      final url = (row['update_url'] ?? '').toString().trim();
      final uri = Uri.tryParse(url);
      final validUrl = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
      if (latest.isEmpty || !_newer(latest, info.version) || !validUrl) return;

      final forced = row['force_update'] == true ||
          (minimum.isNotEmpty && _newer(minimum, info.version));
      if (!forced && _dismissedVersion == latest) return;

      final navContext = widget.navigatorKey.currentState?.overlay?.context;
      if (navContext == null || !navContext.mounted) return;
      final rawMessage = (row['update_message'] ?? '').toString().trim();
      final message = rawMessage.isEmpty
          ? 'Uma nova versao do Velora esta disponivel.'
          : rawMessage;
      _dialogOpen = true;
      try {
        await showDialog<void>(
          context: navContext,
          barrierDismissible: !forced,
          builder: (dialogContext) => PopScope(
            canPop: !forced,
            child: AlertDialog(
              title: const Text('Atualizacao do Velora'),
              content: Text('$message\n\nVersao disponivel: $latest'),
              actions: [
                if (!forced)
                  TextButton(
                    onPressed: () {
                      _dismissedVersion = latest;
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Depois'),
                  ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final opened = await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!opened && dialogContext.mounted) {
                        ScaffoldMessenger.maybeOf(dialogContext)?.showSnackBar(
                          const SnackBar(content: Text('Nao foi possivel abrir o link de atualizacao.')),
                        );
                      }
                    } catch (error) {
                      debugPrint('Velora: erro ao abrir atualizacao: $error');
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.maybeOf(dialogContext)?.showSnackBar(
                          const SnackBar(content: Text('Nao foi possivel abrir o link de atualizacao.')),
                        );
                      }
                    }
                  },
                  child: const Text('Atualizar'),
                ),
              ],
            ),
          ),
        );
      } finally {
        _dialogOpen = false;
      }
    } catch (error) {
      debugPrint('Velora: falha ao consultar atualizacoes: $error');
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
DART

python3 - <<'PY'
from pathlib import Path
import re
p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8')
imp="import 'services/velora_update_gate.dart';\n"
if imp not in s:
    match=re.search(r'^import\s',s,re.M)
    if not match: raise SystemExit('Nao foi encontrado import em lib/main.dart')
    s=s[:match.start()]+imp+s[match.start():]
if 'VeloraUpdateGate(' not in s:
    match=re.search(r'\breturn\s+(?:const\s+)?MaterialApp\s*\(',s)
    if not match: raise SystemExit('MaterialApp nao encontrado. Integracao nao aplicada.')
    start=match.end()
    # Evita criar dois builders/navigatorKeys e gerar Dart invalido.
    nearby=s[start:start+2000]
    if re.search(r'\b(?:builder|navigatorKey)\s*:',nearby):
        raise SystemExit('MaterialApp ja possui builder/navigatorKey. Revisao manual necessaria.')
    key='final GlobalKey<NavigatorState> veloraUpdateNavigatorKey = GlobalKey<NavigatorState>();\n\n'
    if 'veloraUpdateNavigatorKey' not in s:
        class_match=re.search(r'^class\s',s,re.M)
        if not class_match: raise SystemExit('Classe nao encontrada em main.dart')
        s=s[:class_match.start()]+key+s[class_match.start():]
        match=re.search(r'\breturn\s+(?:const\s+)?MaterialApp\s*\(',s)
        start=match.end()
    insertion='''
      navigatorKey: veloraUpdateNavigatorKey,
      builder: (context, child) => VeloraUpdateGate(
        navigatorKey: veloraUpdateNavigatorKey,
        child: child ?? const SizedBox.shrink(),
      ),'''
    s=s[:start]+insertion+s[start:]
p.write_text(s,encoding='utf-8')
PY

echo 'Velora: verificador de atualizacoes configurado.'
