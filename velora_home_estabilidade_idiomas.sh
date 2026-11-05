#!/usr/bin/env bash
set -euo pipefail
# Velora — carrossel manual, idiomas, manutencao e timeout das consultas.
# Rodar DEPOIS de velora_remote_config_idiomas.sh e ANTES do build.
# Preserva login, rotas, modo manutencao e protecoes de estabilidade.
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

# Carrossel remoto: usa home.banners, respeitando enabled e order.
# Se a lista ainda nao existir, mantem o unico banner_url anterior.
# Gestos manuais, botoes de 48 px e textos em widgets acessiveis.
for marker in (
    '  Widget _empty()',
    '  Widget _home(List<Map<String, dynamic>> items) {',
    '  Widget _explore(',
    'VeloraRemoteConfig.home',
    '  Widget _veloraMaintenanceView() {',
):
    if s.count(marker) != 1:
        raise SystemExit(f'ERRO: estrutura da Home inesperada ({marker}). Nada alterado.')
if 'Widget _veloraRemoteBanner()' in s or 'Widget _veloraBannerCarousel()' in s:
    raise SystemExit('ERRO: outra implementacao de banner encontrada. Nada alterado.')

# Estado e controller sao adicionados ao State original; observer ja existente
# (atualizacao ao retornar do segundo plano) continua sendo preservado.
state_anchor = 'class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {'
if s.count(state_anchor) != 1:
    raise SystemExit('ERRO: classe State com observer ausente. Nada alterado.')
s = s.replace(state_anchor, state_anchor + '''
  final PageController _veloraBannerController = PageController();
  int _veloraBannerPage = 0;
''', 1)
dispose_anchor = '    WidgetsBinding.instance.removeObserver(this);'
if s.count(dispose_anchor) != 1 or s.count('    super.dispose();') != 1:
    raise SystemExit('ERRO: dispose/observer inesperados. Nada alterado.')
s = s.replace(dispose_anchor, dispose_anchor + '\n    _veloraBannerController.dispose();', 1)

banner_code = '''  bool _veloraValidBannerUrl(Object? source) {
    if (source is! String || source.trim().isEmpty) return false;
    final uri = Uri.tryParse(source.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  List<Map<String, dynamic>> _veloraActiveBanners() {
    final home = VeloraRemoteConfig.home;
    if (home['show_featured'] != true) return [];
    final raw = home['banners'];
    if (raw is List) {
      final banners = <Map<String, dynamic>>[];
      for (final entry in raw) {
        if (entry is! Map) continue;
        final data = Map<String, dynamic>.from(entry);
        if (data['enabled'] == true &&
            _veloraValidBannerUrl(data['image_url'])) {
          banners.add(data);
        }
      }
      banners.sort((a, b) {
        final orderA = int.tryParse((a['order'] ?? 9999).toString()) ?? 9999;
        final orderB = int.tryParse((b['order'] ?? 9999).toString()) ?? 9999;
        return orderA.compareTo(orderB);
      });
      return banners;
    }
    // Compatibilidade com as versoes antigas do Supabase.
    if (_veloraValidBannerUrl(home['banner_url'])) {
      return [{
        'id': 'legacy',
        'image_url': home['banner_url'],
        'title_pt': home['banner_title_pt'],
        'title_en': home['banner_title_en'],
        'title_es': home['banner_title_es'],
        'description_pt': home['banner_description_pt'],
        'description_en': home['banner_description_en'],
        'description_es': home['banner_description_es'],
      }];
    }
    return [];
  }

  bool _veloraHasRemoteBanner() => _veloraActiveBanners().isNotEmpty;

  String _veloraBannerLocalized(Map<String, dynamic> banner,
      String prefix, String fallbackPt, String fallbackEn, String fallbackEs) {
    final language = VeloraLanguageStore.current.value;
    final suffix = switch (language) {
      VeloraLanguage.ptBR => 'pt',
      VeloraLanguage.en => 'en',
      VeloraLanguage.es => 'es',
    };
    final remote = banner['${prefix}_$suffix'];
    if (remote is String && remote.trim().isNotEmpty) return remote.trim();
    return switch (language) {
      VeloraLanguage.ptBR => fallbackPt,
      VeloraLanguage.en => fallbackEn,
      VeloraLanguage.es => fallbackEs,
    };
  }

  void _veloraGoToBanner(int target, int count) {
    if (target < 0 || target >= count || !_veloraBannerController.hasClients) {
      return;
    }
    _veloraBannerController.animateToPage(target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut);
  }

  Widget _veloraBannerCarousel() {
    final banners = _veloraActiveBanners();
    if (banners.isEmpty) return const SizedBox.shrink();
    final count = banners.length;
    // Se o administrador desativar slides enquanto o app esta aberto,
    // volte para a primeira pagina, evitando um indice fora do novo limite.
    if (_veloraBannerPage >= count) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_veloraBannerController.hasClients) {
          _veloraBannerController.jumpToPage(0);
        }
        setState(() => _veloraBannerPage = 0);
      });
    }
    final current = _veloraBannerPage.clamp(0, count - 1);
    final width = MediaQuery.sizeOf(context).width - 32;
    final textSpace = MediaQuery.textScalerOf(context).scale(70);
final height = width * 9 / 16 + (textSpace > 70 ? textSpace : 70);
    final previousLabel = _veloraTr('Banner anterior', 'Previous banner', 'Banner anterior');
    final nextLabel = _veloraTr('Próximo banner', 'Next banner', 'Siguiente banner');
    final bannerWord = _veloraTr('Banner', 'Banner', 'Banner');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _veloraBannerController,
            itemCount: count,
            onPageChanged: (page) {
              if (mounted) setState(() => _veloraBannerPage = page);
            },
            itemBuilder: (context, index) {
              final item = banners[index];
              final url = item['image_url'] as String;
              final title = _veloraBannerLocalized(item, 'title',
                  'Destaque Velora', 'Featured on Velora', 'Destacado en Velora');
              final description = _veloraBannerLocalized(item, 'description',
                  '', '', '');
              return Semantics(
                container: true,
                label: '$bannerWord ${index + 1} / $count',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ColoredBox(
                    color: const Color(0xFF17121F),
                    child: Column(children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(url,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.movie_filter_outlined,
                              color: Color(0xFFEBC58C), size: 54)),
                        ),
                      ),
                      // Textos separados da imagem: ampliacao da fonte e
                      // leitura de tela nao dependem da arte do banner.
                      Expanded(child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(
                              color: Colors.white, fontSize: 21,
                              fontWeight: FontWeight.bold)),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(description, style: const TextStyle(
                                color: Color(0xFFE4DCE9), fontSize: 14)),
                            ],
                          ],
                        ),
                      )),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        if (count > 1)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              tooltip: previousLabel,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: current > 0
                  ? () => _veloraGoToBanner(current - 1, count) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Semantics(
              liveRegion: true,
              label: '$bannerWord ${current + 1} / $count',
              child: Row(mainAxisSize: MainAxisSize.min,
                children: List.generate(count, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i == current ? Icons.circle : Icons.circle_outlined,
                    size: 10,
                    color: i == current
                      ? const Color(0xFFEBC58C)
                      : const Color(0xFFBDB5C9),
                  ),
                )),
              ),
            ),
            IconButton(
              tooltip: nextLabel,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: current < count - 1
                  ? () => _veloraGoToBanner(current + 1, count) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ]),
      ]),
    );
  }

'''
# The template above uses a stand-in character in Dart interpolations, so
# the outer Python script can safely emit literal '$' characters.
s = s.replace('  Widget _empty()', banner_code + '  Widget _empty()', 1)

home_start = s.index('  Widget _home(List<Map<String, dynamic>> items) {')
home_end = s.index('  Widget _explore(', home_start)
old_home = s[home_start:home_end]
empty_original = '    if (items.isEmpty) return _empty();'
hero_original = '        _hero(items.first),'
if old_home.count(empty_original) != 1 or old_home.count(hero_original) != 1:
    raise SystemExit('ERRO: Home anterior nao reconhecida. Nada alterado.')
new_home = old_home.replace(empty_original, '''    if (items.isEmpty) {
      if (!_veloraHasRemoteBanner()) return _empty();
      // A Home inteira rola em telas baixas e com fontes ampliadas.
      return ListView(children: [
        _veloraBannerCarousel(),
        SizedBox(height: 360, child: _empty()),
      ]);
    }''', 1)
new_home = new_home.replace(hero_original, '''        if (_veloraHasRemoteBanner())
          _veloraBannerCarousel()
        else
          _hero(items.first),''', 1)
s = s[:home_start] + new_home + s[home_end:]
for expected in (
    'Widget _veloraBannerCarousel()',
    'PageView.builder(',
    'onPageChanged:',
    'Banner anterior',
    'banner_description_es',
    'show_featured',
    '_hero(items.first),',
    '_veloraBannerController.dispose();',
):
    if expected not in s:
        raise SystemExit(f'ERRO: implementacao do carrossel incompleta ({expected}). Nada alterado.')
print('OK: banners ativos e ordenados da lista remota, com fallback do banner antigo.')
print('OK: carrossel manual, botoes acessiveis, textos pt/en/es e sem autoplay.')
print('OK: scroll vertical em telas pequenas; login e manutencao preservados.')

# Protecao de estabilidade: impedir que a Home fique aguardando a API para sempre.
# A consulta do catalogo deve dar erro apos 15s; a interface ja possui o
# botao traduzido "Tentar novamente". Nao disfarcar erros com lista vazia.
reload_start = s.find('  void _reload() {')
reload_end = s.find('\n  String _value(', reload_start)
if reload_start < 0 or reload_end < 0:
    raise SystemExit('ERRO: limites de _reload nao reconhecidos. Nada alterado.')
reload_code = s[reload_start:reload_end]
if reload_code.count('_series =') != 1:
    raise SystemExit('ERRO: carregamento do catalogo inesperado. Nada alterado.')
if '.timeout(const Duration(seconds: 15))' not in reload_code:
    match = re.search(r'(?s)(_series\s*=\s*)(.*?)(;)', reload_code)
    if not match or '.from(' not in match.group(2) or '.select(' not in match.group(2):
        raise SystemExit('ERRO: consulta do catalogo nao reconhecida. Nada alterado.')
    expression = match.group(2).rstrip()
    # A chamada ao Supabase retorna Future; o timeout preserva o erro,
    # permitindo que FutureBuilder mostre a tela de recuperacao.
    new_code = (reload_code[:match.start(2)] + expression +
        '.timeout(const Duration(seconds: 15))' +
        reload_code[match.end(2):])
    reload_code = new_code
s = s[:reload_start] + reload_code + s[reload_end:]

# As configuracoes remotas tambem podem demorar quando o Supabase falha.
# Timeout com retorno false conserva o cache em memoria do servico.
refresh_base = 'VeloraRemoteConfig.refresh()'
refresh_guard = ('VeloraRemoteConfig.refresh().timeout(\n'
                 '        const Duration(seconds: 10),\n'
                 '        onTimeout: () => false,\n'
                 '      )')
expected_refreshes = s.count(refresh_base)
if expected_refreshes < 2 or expected_refreshes > 5:
    raise SystemExit(f'ERRO: consultas remotas inesperadas ({expected_refreshes}). Nada alterado.')
# So trocar chamadas ainda sem timeout, suportando uma futura reexecucao do script.
if 'onTimeout: () => false' not in s:
    s = s.replace(refresh_base, refresh_guard)

if '.timeout(const Duration(seconds: 15))' not in s or 'onTimeout: () => false' not in s:
    raise SystemExit('ERRO: limites de espera nao aplicados. Nada alterado.')
if 'Widget _veloraBannerCarousel()' not in s or 'Widget _veloraMaintenanceView()' not in s:
    raise SystemExit('ERRO: banner/manutencao nao preservados. Nada alterado.')
print('OK: catalogo aguarda no maximo 15 segundos; depois exibe erro e tentar novamente.')
print('OK: atualizacao remota aguarda no maximo 10 segundos e preserva cache da sessao.')

# Escrita unica: se alguma verificacao falhar, home_screen.dart permanece intacto.
p.write_text(s, encoding='utf-8')
print('OK: descricao, atualizar catalogo e tela de erro com traducao pt/en/es.')
print('OK: menu Inicio/Home/Inicio atualizado ao mudar o idioma.')
print('OK: boas-vindas remotas, rotas, layout e recarga preservados.')
PY

