#!/usr/bin/env bash
set -euo pipefail
# Velora — traducoes, estabilidade e menu inferior reativo (script consolidado).
# Rodar DEPOIS de velora_remote_config_idiomas.sh e ANTES do build.
# Nao modifica auth, Supabase, rotas, callbacks nem layout.
python3 - <<'PY'
from pathlib import Path
import re

p = Path('lib/screens/home_screen.dart')
if not p.is_file():
    raise SystemExit('ERRO: lib/screens/home_screen.dart ausente. Nada alterado.')
s = p.read_text(encoding='utf-8')
if ('String _veloraTr(' not in s or
    '_veloraRemoteWelcomeMessage()' not in s or
    '  Widget _empty()' not in s):
    raise SystemExit('ERRO: integracao de idiomas/boas-vindas ausente. Nada alterado.')

# Troca apenas as duas frases fixas recriadas pela etapa de acessibilidade.
start = s.index('  Widget _empty()')
end = s.find('  Widget _home(', start)
if end == -1:
    raise SystemExit('ERRO: limite de _empty nao identificado. Nada alterado.')
empty = s[start:end]

def tr(pt, en, es):
    return '_veloraTr(' + ', '.join(map(repr, (pt, en, es))) + ')'

description_pt = 'As minisséries aparecerão aqui assim que forem publicadas.'
description_expr = tr(description_pt,
    'Mini-series will appear here as soon as they are published.',
    'Las miniseries aparecerán aquí en cuanto se publiquen.')
if empty.count(repr(description_pt)) != 1:
    raise SystemExit('ERRO: descricao da Home alterada ou duplicada. Nada alterado.')
empty = empty.replace(repr(description_pt), description_expr, 1)

refresh_pt = 'Atualizar catálogo'
refresh_expr = tr(refresh_pt, 'Refresh catalog', 'Actualizar catálogo')
refresh_pattern = r'\bconst\s+Text\(\s*' + re.escape(repr(refresh_pt))
refresh_match = re.findall(refresh_pattern, empty)
if len(refresh_match) != 1:
    raise SystemExit('ERRO: botao Atualizar catalogo nao identificado. Nada alterado.')
empty = re.sub(refresh_pattern, 'Text(' + refresh_expr, empty, count=1)
s = s[:start] + empty + s[end:]

# Tela de falha: sugestao de conferir a conexao, sem afirmar que todo erro e offline.
# A recuperacao existente por "Tentar novamente" permanece intacta.
def translate_text_literal(source, old, pt, en, es, label):
    expression = tr(pt, en, es)
    # O texto tem de ser um literal de Text(...); nao mexer em outros contextos.
    pattern = r'\b(?:const\s+)?Text\(\s*' + re.escape(repr(old)) + r'(?=\s*[,\)])'
    updated, n = re.subn(pattern, 'Text(' + expression, source, count=1)
    if n == 1:
        return updated
    # Em algumas versoes o script anterior ja traduziu este texto.
    if 'Text(_veloraTr(' + repr(old) in source:
        print(f'NOTA: {label} ja tem traducao dinamica; preservado.')
        return source
    raise SystemExit(f'ERRO: {label} nao localizado no formato esperado. Nada alterado.')

s = translate_text_literal(
    s, 'Não foi possível carregar o catálogo.',
    'Não foi possível carregar o catálogo. Verifique sua conexão e tente novamente.',
    'Could not load the catalog. Check your connection and try again.',
    'No se pudo cargar el catálogo. Comprueba tu conexión e inténtalo de nuevo.',
    'mensagem de falha')
s = translate_text_literal(
    s, 'Tentar novamente', 'Tentar novamente', 'Try again', 'Intentar de nuevo',
    'botao de recuperacao')

# Se o estado de erro foi envolvido em um Center const diretamente, retire apenas
# esse const; filhos que chamam _veloraTr nao podem ser constantes em Dart.
s = re.sub(
    r'\bconst\s+Center\(\s*child:\s*Column\(',
    'Center(child: Column(', s)

# Verifica que nao apagamos a integracao remota nem a acao de recuperacao.
if (s.count('_veloraRemoteWelcomeMessage()') < 2 or
    'VeloraRemoteConfig' not in s or
    'setState(_reload)' not in s):
    raise SystemExit('ERRO: integracao remota ou recarga nao reconhecida. Nada alterado.')

# Menu inferior reativo: em espanhol mostra 'Inicio' (sem acento) e
# acompanha o ValueNotifier sem recriar o app e sem alterar as rotas.
anchor = 'bottomNavigationBar: NavigationBar('
if s.count(anchor) != 1:
    raise SystemExit(f'ERRO: NavigationBar esperada uma vez, obtidas {s.count(anchor)}; nenhuma alteracao.')
start = s.index(anchor)
open_pos = start + len(anchor) - 1

# Encontra o fechamento exato de NavigationBar(...), incluindo os widgets aninhados.
def closing_paren(source, pos):
    depth = 0
    quote = None
    triple = False
    escaped = False
    comment = None
    i = pos
    while i < len(source):
        c = source[i]
        nxt = source[i:i+2]
        if comment == 'line':
            if c == '\n': comment = None
            i += 1; continue
        if comment == 'block':
            if nxt == '*/': comment = None; i += 2
            else: i += 1
            continue
        if quote:
            if escaped: escaped = False; i += 1; continue
            if c == '\\': escaped = True; i += 1; continue
            if triple and source[i:i+3] == quote*3:
                quote = None; triple = False; i += 3; continue
            if not triple and c == quote:
                quote = None; i += 1; continue
            i += 1; continue
        if nxt == '//': comment = 'line'; i += 2; continue
        if nxt == '/*': comment = 'block'; i += 2; continue
        if c in ("'", '"'):
            quote = c
            triple = source[i:i+3] == c*3
            i += 3 if triple else 1
            continue
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0: return i
        i += 1
    raise SystemExit('ERRO: NavigationBar sem fechamento identificado; nenhuma alteracao.')

end = closing_paren(s, open_pos)
inner = s[open_pos+1:end]
if 'destinations:' not in inner or 'NavigationDestination(' not in inner:
    raise SystemExit('ERRO: destinos de navegacao ausentes; nenhuma alteracao.')
# Nao confiar em um estado antigo para a traducao do botao Inicio:
# o novo builder passa explicitamente o idioma selecionado.
pattern = r"label:\s*_veloraTr\(\s*'Início'\s*,\s*'Home'\s*,\s*'Inicio'\s*\)"
replacement = ("label: switch (selectedLanguage) {\n"
               "                VeloraLanguage.ptBR => 'Início',\n"
               "                VeloraLanguage.en => 'Home',\n"
               "                VeloraLanguage.es => 'Inicio',\n"
               "              }")
inner, count = re.subn(pattern, replacement, inner)
if count != 1:
    raise SystemExit(f'ERRO: traducao do botao Inicio nao localizada unicamente ({count}); nenhuma alteracao.')
wrapped = (
    'bottomNavigationBar: ValueListenableBuilder<VeloraLanguage>(\n'
    '        valueListenable: VeloraLanguageStore.current,\n'
    '        builder: (context, selectedLanguage, child) => NavigationBar('
    + inner + ')\n'
    '      )'
)
s = s[:start] + wrapped + s[end+1:]
if s.count('bottomNavigationBar: ValueListenableBuilder<VeloraLanguage>(') != 1:
    raise SystemExit('ERRO: resultado do menu inconsistente; nada alterado.')

# Escrita unica: se alguma verificacao falhar, home_screen.dart permanece intacto.
p.write_text(s, encoding='utf-8')
print('OK: descricao, atualizar catalogo e tela de erro com traducao pt/en/es.')
print('OK: menu Inicio/Home/Inicio atualizado ao mudar o idioma.')
print('OK: boas-vindas remotas, rotas, layout e recarga preservados.')
PY
