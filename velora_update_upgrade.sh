#!/usr/bin/env bash
set -euo pipefail

# Velora: consulta versoes publicadas em public.app_versions e apresenta
# aviso de atualizacao no aplicativo Flutter.
# Executar apos scripts que geram/modificam lib/main.dart e antes de flutter pub get.

if [[ ! -f pubspec.yaml || ! -f lib/main.dart ]]; then
  echo 'Erro: execute na raiz do projeto Flutter gerado.' >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
p = Path('pubspec.yaml')
s = p.read_text(encoding='utf-8')
for package, version in [('package_info_plus', '^8.0.0'), ('url_launcher', '^6.3.0')]:
    if f'{package}:' not in s:
        if 'dependencies:\n' not in s:
            raise SystemExit('Secao dependencies nao encontrada no pubspec.yaml')
        s = s.replace('dependencies:\n', f'dependencies:\n  {package}: {version}\n', 1)
        p.write_text(s, encoding='utf-8')
PY

mkdir -p lib/services
cat > lib/services/velora_update_gate.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Adicione este widget em MaterialApp.builder e forneca navigatorKey.
class VeloraUpdateGate extends StatefulWidget {
  const VeloraUpdateGate({super.key, required this.child, required this.navigatorKey});
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<VeloraUpdateGate> createState() => _VeloraUpdateGateState();
}

class _VeloraUpdateGateState extends State<VeloraUpdateGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  List<int> _numbers(String version) {
    final cleaned = version.trim().split('+').first.split('-').first;
    return cleaned.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  }

  bool _isNewer(String remote, String installed) {
    final a = _numbers(remote);
    final b = _numbers(installed);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  Future<void> _check() async {
    if (_checked || !mounted) return;
    _checked = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final response = await Supabase.instance.client
          .from('app_versions')
          .select('latest_version, minimum_version, update_url, update_message, force_update')
          .eq('platform', 'android')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response == null || !mounted) return;
      final latest = (response['latest_version'] ?? '').toString();
      final minimum = (response['minimum_version'] ?? '').toString();
      if (latest.isEmpty || !_isNewer(latest, info.version)) return;
      final url = (response['update_url'] ?? '').toString().trim();
      final forced = url.isNotEmpty && (response['force_update'] == true ||
          (minimum.isNotEmpty && _isNewer(minimum, info.version)));
      final message = (response['update_message'] ??
              'Uma nova versao do Velora esta disponivel.')
          .toString();
      if (!mounted) return;
      final context = widget.navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: !forced,
        builder: (dialogContext) => PopScope(
          canPop: !forced,
          child: AlertDialog(
            title: const Text('Atualizacao do Velora'),
            content: Text('$message\n\nVersao disponivel: $latest'),
            actions: [
              if (!forced)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Depois'),
                ),
              if (url.isNotEmpty)
                FilledButton(
                  onPressed: () async {
                    final uri = Uri.tryParse(url);
                    if (uri != null &&
                        (uri.scheme == 'https' || uri.scheme == 'http')) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text('Atualizar'),
                ),
            ],
          ),
        ),
      );
    } catch (error) {
      // Falha de rede nao deve impedir o aplicativo de abrir.
      debugPrint('Velora: nao foi possivel verificar atualizacoes: $error');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
DART

python3 - <<'PY'
from pathlib import Path
import re
p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')
imp = "import 'services/velora_update_gate.dart';\n"
if imp not in s:
    # Insere antes do primeiro import para nao afetar declaracoes Dart.
    match = re.search(r'^import\s', s, re.M)
    if not match:
        raise SystemExit('Nao foi encontrado import em lib/main.dart')
    s = s[:match.start()] + imp + s[match.start():]

if 'VeloraUpdateGate(' not in s:
    # A estrutura original do projeto tem MaterialApp dentro de MiniSeriesApp.
    # Em vez de editar as telas, acrescentamos um builder no MaterialApp.
    mat = re.search(r'\breturn\s+(?:const\s+)?MaterialApp\s*\(', s)
    if not mat:
        raise SystemExit('Nao foi encontrado return MaterialApp( em lib/main.dart; integracao nao aplicada')
    start = mat.end()
    # Chave global no escopo do arquivo, acessivel pelo MaterialApp e pelo gate.
    key = 'final GlobalKey<NavigatorState> veloraUpdateNavigatorKey = GlobalKey<NavigatorState>();\n\n'
    if 'veloraUpdateNavigatorKey' not in s:
        match = re.search(r'^class\s', s, re.M)
        if not match:
            raise SystemExit('Nao foi encontrada declaracao de classe em lib/main.dart')
        s = s[:match.start()] + key + s[match.start():]
        mat = re.search(r'\breturn\s+(?:const\s+)?MaterialApp\s*\(', s)
        start = mat.end()
    insertion = '''
      navigatorKey: veloraUpdateNavigatorKey,
      builder: (context, child) => VeloraUpdateGate(
        navigatorKey: veloraUpdateNavigatorKey,
        child: child ?? const SizedBox.shrink(),
      ),'''
    s = s[:start] + insertion + s[start:]
p.write_text(s, encoding='utf-8')
PY

echo 'Velora: verificador de atualizacoes integrado ao MaterialApp.'
echo 'Para exibir o botao Atualizar, preencha update_url com um link HTTPS valido na tabela app_versions.'
