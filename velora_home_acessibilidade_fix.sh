#!/usr/bin/env bash
set -euo pipefail

# Velora: ajustes de acessibilidade para Inicio, Explorar e navegacao.
# Execute apos os scripts que criam/modificam lib/screens/home_screen.dart.
python3 - <<'PY'
from pathlib import Path
import re
p = Path('lib/screens/home_screen.dart')
if not p.is_file():
    raise SystemExit('ERRO: lib/screens/home_screen.dart nao encontrado.')
s = p.read_text(encoding='utf-8')
if 'class _HomeScreenState' not in s or 'Widget _empty()' not in s:
    raise SystemExit('ERRO: estrutura HomeScreen nao reconhecida; nada alterado.')

# Replace only the empty-state widget; leave catalog/auth functionality untouched.
start = s.index('  Widget _empty()')
end = s.find('  Widget _home(', start)
if end < 0:
    raise SystemExit('ERRO: limite de _empty nao localizado; nada alterado.')
new_empty = '''  Widget _empty() => LayoutBuilder(builder: (context, constraints) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: (constraints.maxHeight - 56).clamp(0.0, double.infinity)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.movie_filter_outlined, color: _gold, size: 58),
          const SizedBox(height: 18),
          const Text('O próximo capítulo começa aqui',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('As minisséries aparecerão aqui assim que forem publicadas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFBDB5C9))),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh),
            label: const Text('Atualizar catálogo', textAlign: TextAlign.center),
          ),
        ]),
      ),
    );
  });

'''
s = s[:start] + new_empty + s[end:]

# Let the search hint take more room; allow empty results to wrap with margins.
old = "          prefixIcon: const Icon(Icons.search, color: _gold),"
if old not in s:
    raise SystemExit('ERRO: campo de busca nao reconhecido; nada alterado.')
s = s.replace(old, "          prefixIcon: const Icon(Icons.search, color: _gold),\n          isDense: true,", 1)
old = "? const Center(child: Text('Nenhuma minissérie encontrada.'))"
if old not in s:
    raise SystemExit('ERRO: mensagem de busca vazia nao reconhecida; nada alterado.')
s = s.replace(old, "? const Center(child: Padding(\n                padding: EdgeInsets.symmetric(horizontal: 24),\n                child: Text('Nenhuma minissérie encontrada.',\n                    textAlign: TextAlign.center)))", 1)

# Give the navigation a little more height and allow Flutter to adapt labels.
old = '      bottomNavigationBar: NavigationBar(\n'
if old not in s:
    raise SystemExit('ERRO: NavigationBar nao encontrada; nada alterado.')
s = s.replace(old, '      bottomNavigationBar: NavigationBar(\n        height: 96,\n', 1)

p.write_text(s, encoding='utf-8')
print('OK: Inicio rolavel, Explorar com mensagem centralizada e navegacao ajustada.')
PY
