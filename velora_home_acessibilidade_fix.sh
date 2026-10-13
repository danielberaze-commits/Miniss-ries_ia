#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
import re
p=Path('lib/screens/home_screen.dart')
if not p.is_file():
    raise SystemExit('ERRO: home_screen.dart nao encontrado.')
s=p.read_text(encoding='utf-8')
if 'class _HomeScreenState' not in s or 'Widget _empty()' not in s:
    raise SystemExit('ERRO: estrutura HomeScreen nao reconhecida.')
# Preserve the previously validated scrollable empty-state fix.
a=s.index('  Widget _empty()')
b=s.find('  Widget _home(',a)
if b<0: raise SystemExit('ERRO: limite da tela vazia nao encontrado.')
empty='''  Widget _empty() => LayoutBuilder(builder: (context, constraints) {
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
s=s[:a]+empty+s[b:]
# Compact hint, retaining accessibility through TextField's semantic label wrapper.
s,n=re.subn(r"hintText:\s*'Buscar minisséries'", "hintText: 'Buscar'", s, count=1)
if n!=1 and "hintText: 'Buscar'" not in s:
    raise SystemExit('ERRO: texto do campo de busca nao encontrado.')
# Replace the entire empty-results Center, including any previously inserted padding.
needle="'Nenhuma minissérie encontrada.'"
idx=s.find(needle)
if idx<0: raise SystemExit('ERRO: mensagem de busca nao encontrada; nada gravado.')
start=s.rfind('?',0,idx)
end=s.find(': GridView.builder',idx)
if start<0 or end<0 or idx-start>350 or end-idx>350:
    raise SystemExit('ERRO: estrutura da mensagem de busca nao reconhecida; nada gravado.')
replacement="""? const Center(child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text('Nenhuma minissérie encontrada.',
                    textAlign: TextAlign.center)))
          """
s=s[:start]+replacement+s[end:]
# Shorter destination text keeps a single line with large system fonts.
s,n=re.subn(r"label:\s*'Minha Lista'", "label: 'Lista'", s, count=1)
if n!=1 and "label: 'Lista'" not in s:
    raise SystemExit('ERRO: destino Minha Lista nao encontrado; nada gravado.')
# Ensure selected search icon has visible contrast against the purple indicator.
pattern=r"NavigationDestination\(icon:\s*(?:const\s+)?Icon\(Icons\.search\),\s*label:\s*'Explorar'\)"
replace="NavigationDestination(icon: Icon(Icons.search),\n               selectedIcon: Icon(Icons.search, color: _gold), label: 'Explorar')"
s,n=re.subn(pattern,replace,s,count=1)
if n!=1 and 'selectedIcon: Icon(Icons.search, color: _gold)' not in s:
    raise SystemExit('ERRO: icone Explorar nao reconhecido; nada gravado.')
# Preserve or add height only once.
if 'bottomNavigationBar: NavigationBar(' not in s:
    raise SystemExit('ERRO: NavigationBar nao encontrada; nada gravado.')
nav=s.index('bottomNavigationBar: NavigationBar(')
near=s[nav:nav+130]
if not re.search(r'\bheight\s*:',near):
    s=s[:nav]+s[nav:].replace('bottomNavigationBar: NavigationBar(', 'bottomNavigationBar: NavigationBar(\n        height: 96,',1)
p.write_text(s,encoding='utf-8')
print('OK: Inicio preservado; busca compacta; mensagem centralizada; Lista e icone Explorar ajustados.')
PY
