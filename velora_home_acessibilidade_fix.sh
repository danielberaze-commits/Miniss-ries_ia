#!/usr/bin/env bash
set -euo pipefail
# Executar apos os scripts de traducao e responsividade.
python3 - <<'PY'
from pathlib import Path
p = Path('lib/screens/home_screen.dart')
if not p.is_file():
    raise SystemExit('ERRO: home_screen.dart nao encontrado.')
s = p.read_text(encoding='utf-8')
if 'class _HomeScreenState' not in s or 'Widget _empty()' not in s:
    raise SystemExit('ERRO: estrutura da tela nao reconhecida.')

# Validacoes antes de gravar: codigo real observado no diagnostico do Actions.
hint_old = "hintText: _veloraTr('Buscar minisséries', 'Search mini-series', 'Buscar miniseries'),"
hint_new = "hintText: _veloraTr('Buscar', 'Search', 'Buscar'),"
empty_old = "? Center(child: Text(_veloraTr('Nenhuma minissérie encontrada.', 'No mini-series found.', 'No se encontraron miniseries.')))"
empty_new = """? Center(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _veloraTr('Nenhuma minissérie encontrada.', 'No mini-series found.', 'No se encontraron miniseries.'),
                  textAlign: TextAlign.center,
                ),
              ))"""
list_old = "label: _veloraTr('Minha Lista', 'My List', 'Mi lista')"
list_new = "label: _veloraTr('Lista', 'List', 'Lista')"
search_old = "NavigationDestination(icon: Icon(Icons.search), label: _veloraTr('Explorar', 'Explore', 'Explorar'))"
search_new = "NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search, color: _gold), label: _veloraTr('Explorar', 'Explore', 'Explorar'))"

for name, old, new in [
    ('campo de busca', hint_old, hint_new),
    ('mensagem vazia', empty_old, empty_new),
    ('rotulo Lista', list_old, list_new),
    ('icone Explorar', search_old, search_new),
]:
    if s.count(old) != 1:
        raise SystemExit(f'ERRO: {name} nao corresponde ao diagnostico (ocorrencias={s.count(old)}); nada alterado.')

start = s.index('  Widget _empty()')
end = s.find('  Widget _home(', start)
if end < 0:
    raise SystemExit('ERRO: limite do estado vazio nao encontrado; nada alterado.')
# Preserva a solucao de rolagem que ja foi validada no aparelho.
empty = '''  Widget _empty() => LayoutBuilder(builder: (context, constraints) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: (constraints.maxHeight - 56).clamp(0.0, double.infinity)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.movie_filter_outlined, color: _gold, size: 58),
          const SizedBox(height: 18),
          const Text('O próximo capítulo começa aqui', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('As minisséries aparecerão aqui assim que forem publicadas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFBDB5C9))),
          const SizedBox(height: 20),
          OutlinedButton.icon(onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh),
            label: const Text('Atualizar catálogo', textAlign: TextAlign.center)),
        ]),
      ),
    );
  });

'''
s = s[:start] + empty + s[end:]
for _, old, new in [
    ('campo de busca', hint_old, hint_new),
    ('mensagem vazia', empty_old, empty_new),
    ('rotulo Lista', list_old, list_new),
    ('icone Explorar', search_old, search_new),
]:
    s = s.replace(old, new, 1)
if 'bottomNavigationBar: NavigationBar(' not in s:
    raise SystemExit('ERRO: NavigationBar nao encontrada; nada alterado.')
nav = s.index('bottomNavigationBar: NavigationBar(')
if 'height:' not in s[nav:nav+100]:
    s = s[:nav] + s[nav:].replace('bottomNavigationBar: NavigationBar(', 'bottomNavigationBar: NavigationBar(\n        height: 96,', 1)
p.write_text(s, encoding='utf-8')
print('OK: inicio rolavel, busca traduzida curta, mensagem centralizada, Lista e contraste ajustados.')
PY
