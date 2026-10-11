#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
import re, os
home=Path('lib/screens/home_screen.dart')
if not home.exists(): raise SystemExit('ERRO: home_screen.dart ausente')
s=home.read_text()
langs=[p for p in Path('lib').rglob('*.dart') if 'class VeloraLanguageStore' in p.read_text()]
if len(langs)!=1: raise SystemExit('ERRO: modulo de idiomas nao identificado')
imp="import '%s';" % os.path.relpath(langs[0],home.parent).replace('\\','/')
if imp not in s:
    match=re.search(r'^import [^\n]+;',s,re.M)
    if not match: raise SystemExit('ERRO: import nao identificado')
    s=s[:match.end()]+'\n'+imp+s[match.end():]
helper='''
String _veloraTr(String pt, String en, String es) {
  switch (VeloraLanguageStore.current.value) {
    case VeloraLanguage.ptBR: return pt;
    case VeloraLanguage.en: return en;
    case VeloraLanguage.es: return es;
  }
}
'''
if 'String _veloraTr(' not in s:
    idx=s.find('class HomeScreen')
    if idx<0: raise SystemExit('ERRO: HomeScreen nao encontrada')
    s=s[:idx]+helper+'\n'+s[idx:]
translations=[
('DESTAQUE VELORA','FEATURED ON VELORA','DESTACADO EN VELORA'),
('Ver episódios','Watch episodes','Ver episodios'),
('Salvar na Minha Lista','Save to My List','Guardar en Mi lista'),
('O próximo capítulo começa aqui','The next chapter starts here','El próximo capítulo comienza aquí'),
('As minisséries aparecerão aqui assim que forem publicadas.','Mini-series will appear here once published.','Las miniseries aparecerán aquí cuando se publiquen.'),
('Atualizar catálogo','Refresh catalog','Actualizar catálogo'),
('Novidades','New releases','Novedades'),
('Minisséries Velora','Velora mini-series','Miniseries Velora'),
('Buscar minisséries','Search mini-series','Buscar miniseries'),
('Nenhuma minissérie encontrada.','No mini-series found.','No se encontraron miniseries.'),
('Sua lista está vazia. Salve uma minissérie para vê-la aqui.','Your list is empty. Save a mini-series to see it here.','Tu lista está vacía. Guarda una miniserie para verla aquí.'),
('Usuário Velora','Velora user','Usuario Velora'),
('Sair da conta','Sign out','Cerrar sesión'),
('Não foi possível carregar o catálogo.','Could not load the catalog.','No se pudo cargar el catálogo.'),
('Tentar novamente','Try again','Intentar de nuevo'),
('Início','Home','Inicio'),
('Explorar','Explore','Explorar'),
('Minha Lista','My List','Mi lista'),
('Perfil','Profile','Perfil'),
]
for pt,en,es in translations:
    q=repr(pt)
    expr='_veloraTr(%s, %s, %s)'%(repr(pt),repr(en),repr(es))
    s=s.replace('const Text('+q,'Text('+expr)
    s=s.replace('Text('+q,'Text('+expr)
    for prefix in ('label: ','tooltip: ','hintText: ','?? ','_shelf('):
        s=s.replace(prefix+q,prefix+expr)
s=s.replace('return const Center(child: Padding(padding: EdgeInsets.all(24),','return Center(child: Padding(padding: const EdgeInsets.all(24),')
s=s.replace('? const Center(child: Text(', '? Center(child: Text(')
s=s.replace('destinations: const [','destinations: [')
# const Center and const Text containers cannot contain expressions; ensure no const ancestors.
s=s.replace('return const Center(child: Padding(', 'return Center(child: Padding(')
home.write_text(s)
print('OK: traducoes da home, busca, lista e menu instaladas')
PY
