#!/usr/bin/env bash
set -euo pipefail

# Velora update check: run after setup.sh and other UI upgrade scripts,
# before flutter pub get / flutter build.
mkdir -p lib

python3 - <<'PY'
from pathlib import Path
p = Path('lib/main.dart')
if not p.exists():
    raise SystemExit('ERRO: lib/main.dart nao existe. Execute setup.sh primeiro.')
s = p.read_text()
if 'velora_update_gate.dart' in s:
    print('Velora update gate ja instalado.')
else:
    needle = "import 'package:flutter/material.dart';"
    if needle not in s:
        raise SystemExit('ERRO: import Flutter nao encontrado em lib/main.dart')
    s = s.replace(needle, needle + "\nimport 'velora_update_gate.dart';", 1)
    # Wrap home widget without changing authentication flow.
    import re
    pattern = r'home:\s*Supabase\.instance\.client\.auth\.currentSession\s*==\s*null\s*\?\s*const\s+AuthScreen\(\)\s*:\s*const\s+HomeScreen\(\)\s*,'
    replacement = ('home: VeloraUpdateGate(\n'
                   '          child: Supabase.instance.client.auth.currentSession == null\n'
                   '              ? const AuthScreen()\n'
                   '              : const HomeScreen(),\n'
                   '        ),')
    s, n = re.subn(pattern, replacement, s, count=1)
    if n != 1:
        raise SystemExit('ERRO: estrutura da home nao reconhecida. Nada foi alterado.')
    p.write_text(s)
    print('Velora update gate conectado ao main.dart.')
PY

cat > lib/velora_update_gate.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Checks the public version record once when the app opens.
/// Fails open on network errors so the app remains usable offline.
class VeloraUpdateGate extends StatefulWidget {
  final Widget child;
  const VeloraUpdateGate({super.key, required this.child});

  @override
  State<VeloraUpdateGate> createState() => _VeloraUpdateGateState();
}

class _VeloraUpdateGateState extends State<VeloraUpdateGate> {
  static const String _installedVersion = String.fromEnvironment(
    'VELORA_APP_VERSION', defaultValue: '1.0.0');
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  int _compareVersions(String a, String b) {
    List<int> parse(String value) {
      final clean = value.split('+').first.split('-').first;
      return clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    }
    final x = parse(a);
    final y = parse(b);
    for (var i = 0; i < 3; i++) {
      final left = i < x.length ? x[i] : 0;
      final right = i < y.length ? y[i] : 0;
      if (left != right) return left.compareTo(right);
    }
    return 0;
  }

  Future<void> _check() async {
    if (_checked) return;
    _checked = true;
    try {
      final result = await Supabase.instance.client
          .from('app_versions')
          .select('latest_version, minimum_version, update_url, update_message, force_update')
          .eq('platform', 'android')
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      if (!mounted || result == null) return;
      final latest = (result['latest_version'] ?? '').toString();
      final minimum = (result['minimum_version'] ?? '').toString();
      final url = (result['update_url'] ?? '').toString().trim();
      if (latest.isEmpty || _compareVersions(latest, _installedVersion) <= 0) return;
      // Never display an update action without a valid HTTPS destination.
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
      final forced = result['force_update'] == true ||
          (minimum.isNotEmpty && _compareVersions(minimum, _installedVersion) > 0);
      final message = (result['update_message'] ?? '').toString().trim();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: !forced,
        builder: (dialogContext) => PopScope(
          canPop: !forced,
          child: AlertDialog(
            title: const Text('Atualização do Velora'),
            content: Text(message.isEmpty
                ? 'A versão $latest do Velora está disponível.'
                : '$message\n\nNova versão: $latest'),
            actions: [
              if (!forced)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Mais tarde'),
                ),
              FilledButton(
                onPressed: () async {
                  try {
                    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!opened && dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Não foi possível abrir o link de atualização.')),
                      );
                    }
                  } catch (_) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Não foi possível abrir o link de atualização.')),
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
    } catch (e) {
      debugPrint('Velora: consulta de atualização indisponível: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
DART

# The package is only added if absent. Existing dependencies are preserved.
python3 - <<'PY'
from pathlib import Path
p = Path('pubspec.yaml')
if not p.exists():
    raise SystemExit('ERRO: pubspec.yaml nao encontrado.')
s = p.read_text()
if 'url_launcher:' not in s:
    marker = 'dependencies:\n'
    if marker not in s:
        raise SystemExit('ERRO: dependencies nao encontrado em pubspec.yaml')
    s = s.replace(marker, marker + '  url_launcher: ^6.3.1\n', 1)
    p.write_text(s)
print('Dependencias de atualizacao prontas.')
PY

echo 'Velora update upgrade concluido.'
