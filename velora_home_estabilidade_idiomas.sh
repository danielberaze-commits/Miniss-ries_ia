#!/usr/bin/env bash
set -euo pipefail
# Velora — ajuste pontual de textos da Home após acessibilidade e config remota.
# Rodar DEPOIS de velora_remote_config_idiomas.sh e ANTES do build.
# Não modifica auth, Supabase, rotas, callbacks nem layout.
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
p.write_text(s, encoding='utf-8')
print('OK: descricao, atualizar catalogo e tela de erro com traducao pt/en/es.')
print('OK: boas-vindas remotas, navegacao e recarga preservadas.')
PY
