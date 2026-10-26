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

# Primeiro banner remoto: utiliza a configuracao home existente no Supabase.
# Mantem a Home vazia acessivel quando nao ha imagem configurada.
# O destaque padrao de uma serie publicada continua quando o banner esta oculto.
banner_method = '  Widget _veloraRemoteBanner() {'
if banner_method in s:
    raise SystemExit('ERRO: banner remoto duplicado. Nada alterado.')
for marker in (
    '  Widget _empty()',
    '  Widget _home(List<Map<String, dynamic>> items) {',
    '  Widget _explore(',
    'VeloraRemoteConfig.home',
    '  Widget _veloraMaintenanceView() {',
):
    if s.count(marker) != 1:
        raise SystemExit(f'ERRO: estrutura esperada nao encontrada de forma unica ({marker}). Nada alterado.')

banner_code = '''  bool _veloraHasRemoteBanner() {
    final config = VeloraRemoteConfig.home;
    if (config['show_featured'] != true) return false;
    final source = config['banner_url'];
    if (source is! String || source.trim().isEmpty) return false;
    final uri = Uri.tryParse(source.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  String _veloraBannerLocalized(String baseKey,
      String fallbackPt, String fallbackEn, String fallbackEs) {
    final language = VeloraLanguageStore.current.value;
    final suffix = switch (language) {
      VeloraLanguage.ptBR => 'pt',
      VeloraLanguage.en => 'en',
      VeloraLanguage.es => 'es',
    };
    final remote = VeloraRemoteConfig.home['${baseKey}_$suffix'];
    if (remote is String && remote.trim().isNotEmpty) {
      return remote.trim();
    }
    return switch (language) {
      VeloraLanguage.ptBR => fallbackPt,
      VeloraLanguage.en => fallbackEn,
      VeloraLanguage.es => fallbackEs,
    };
  }

  Widget _veloraRemoteBanner() {
    final value = VeloraRemoteConfig.home['banner_url'];
    final imageUrl = value is String ? value.trim() : '';
    final title = _veloraBannerLocalized('banner_title',
        'Destaque Velora', 'Featured on Velora', 'Destacado en Velora');
    final description = _veloraBannerLocalized('banner_description',
        '', '', '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: const Color(0xFF17121F),
                      child: const Center(child: Icon(
                        Icons.movie_filter_outlined,
                        color: Color(0xFFEBC58C), size: 54))),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x1108070E), Color(0xBB08070E)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('VELORA ORIGINALS',
                      style: TextStyle(color: Color(0xFFEBC58C),
                        letterSpacing: 1.5, fontSize: 11,
                        fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(title, maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white,
                        fontSize: 23, fontWeight: FontWeight.bold)),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(description, maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFE4DCE9),
                          fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

'''
s = s.replace('  Widget _empty()', banner_code + '  Widget _empty()', 1)
home_start = s.index('  Widget _home(List<Map<String, dynamic>> items) {')
home_end = s.index('  Widget _explore(', home_start)
old_home = s[home_start:home_end]
empty_original = '    if (items.isEmpty) return _empty();'
hero_original = '        _hero(items.first),'
if old_home.count(empty_original) != 1 or old_home.count(hero_original) != 1:
    raise SystemExit('ERRO: estrutura de estado vazio ou destaque original alterada. Nada alterado.')
new_home = old_home.replace(empty_original, '''    if (items.isEmpty) {
      if (!_veloraHasRemoteBanner()) return _empty();
      return Column(children: [
        _veloraRemoteBanner(),
        Expanded(child: _empty()),
      ]);
    }''', 1)
new_home = new_home.replace(hero_original, '''        if (_veloraHasRemoteBanner())
          _veloraRemoteBanner()
        else
          _hero(items.first),''', 1)
s = s[:home_start] + new_home + s[home_end:]
for expected in (
    'Widget _veloraRemoteBanner()',
    'Uri.tryParse(source.trim())',
    'Expanded(child: _empty())',
    '_hero(items.first),',
    'show_featured',
    'banner_url',
):
    if expected not in s:
        raise SystemExit(f'ERRO: verificacao do banner falhou ({expected}). Nada alterado.')
print('OK: um banner remoto opcional acima da Home vazia e no destaque do catalogo.')
print('OK: imagem HTTPS, titulo e descricao em pt/en/es; sem botoes ou rotas ficticias.')
print('OK: modo manutencao, mensagem remota e destaque padrao preservados.')

# Escrita unica: se alguma verificacao falhar, home_screen.dart permanece intacto.
p.write_text(s, encoding='utf-8')
print('OK: descricao, atualizar catalogo e tela de erro com traducao pt/en/es.')
print('OK: menu Inicio/Home/Inicio atualizado ao mudar o idioma.')
print('OK: boas-vindas remotas, rotas, layout e recarga preservados.')
PY
