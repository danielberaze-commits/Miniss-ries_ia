#!/usr/bin/env bash
set -euo pipefail

# Velora - ajustes iniciais de responsividade e acessibilidade.
# Executar APOS todos os scripts que personalizam/traduzem home_screen.dart
# e ANTES de flutter pub get / flutter build.
python3 - <<'PY'
from pathlib import Path
p = Path('lib/screens/home_screen.dart')
if not p.exists():
    raise SystemExit('ERRO: lib/screens/home_screen.dart nao encontrado; nada alterado.')
s = p.read_text(encoding='utf-8')
original = s
marker = '// VELORA_RESPONSIVE_A11Y_V1'
if marker in s:
    print('Velora: ajustes ja aplicados; nenhuma alteracao necessaria.')
    raise SystemExit(0)

def replace_once(old, new, label):
    global s
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'ERRO: trecho {label} encontrado {n} vezes (esperado 1). Arquivo preservado.')
    s = s.replace(old, new, 1)

# Mantem as proporcoes dos posters, mas ajusta altura da prateleira a fontes ampliadas.
replace_once('SizedBox(height: 230, child: ListView.separated(',
'''SizedBox(
        height: 230 + (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0.0, 60.0) * 3,
        child: ListView.separated(''', 'prateleira')

# Aumenta espaco do destaque conforme o tamanho do texto, sem mudar a arte.
replace_once('height: 395,\n      child: Stack(',
'''height: 395 + (MediaQuery.textScalerOf(context).scale(33) - 33).clamp(0.0, 100.0) * 3,
      child: Stack(''', 'destaque')

# Wrap evita estouro horizontal dos botoes no banner em telas compactas.
replace_once('Row(children: [\n            FilledButton.icon(',
'''Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilledButton.icon(''', 'botoes destaque')

# Substitui grade fixa por colunas e largura calculadas no espaco disponivel.
old = '''           : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: .62,
                crossAxisSpacing: 14, mainAxisSpacing: 16),
              itemCount: found.length,
              itemBuilder: (_, i) => _cover(found[i], width: 165),
            )),'''
new = '''           : LayoutBuilder(builder: (context, constraints) {
               const gap = 14.0;
               const horizontalPadding = 18.0;
               final available = (constraints.maxWidth - horizontalPadding * 2).clamp(1.0, double.infinity);
               final columns = ((available + gap) / 165).floor().clamp(1, 6);
               final tileWidth = (available - gap * (columns - 1)) / columns;
               final extraTextHeight = (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0.0, 60.0) * 2;
               return GridView.builder(
                 padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                   crossAxisCount: columns,
                   mainAxisExtent: tileWidth * 1.42 + 42 + extraTextHeight,
                   crossAxisSpacing: gap, mainAxisSpacing: 16),
                 itemCount: found.length,
                 itemBuilder: (_, i) => _cover(found[i], width: tileWidth),
               );
             })),'''
import re
pattern = r'\s*: GridView\.builder\(\s*padding: const EdgeInsets\.symmetric\(horizontal: 18\),\s*gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount\(\s*crossAxisCount: 2, childAspectRatio: \.62,\s*crossAxisSpacing: 14, mainAxisSpacing: 16\),\s*itemCount: found.length,\s*itemBuilder: \(\_, i\) => _cover\(found\[i\], width: 165\),\s*\)\),'
match = list(re.finditer(pattern, s))
if len(match) != 1:
    raise SystemExit(f'ERRO: grade encontrada {len(match)} vezes; arquivo preservado.')
s = s[:match[0].start()] + '\n' + new + s[match[0].end():]

# Tooltips legiveis por leitores de tela para os botoes sem texto.
replace_once('icon: const Icon(Icons.search),\n            onPressed:',
             "tooltip: 'Buscar minisséries',\n            icon: const Icon(Icons.search),\n            onPressed:", 'botao buscar')
replace_once('IconButton(icon: const Icon(Icons.account_circle_outlined),',
             "IconButton(tooltip: 'Abrir perfil', icon: const Icon(Icons.account_circle_outlined),", 'botao perfil')
replace_once('trailing: IconButton(icon: const Icon(Icons.bookmark_remove_outlined),',
             "trailing: IconButton(tooltip: 'Remover da Minha Lista', icon: const Icon(Icons.bookmark_remove_outlined),", 'remover favorito')

# Reduz a decodificacao de imagens de capas para a largura efetivamente exibida.
replace_once('Image.network(url, fit: BoxFit.cover,',
'''Image.network(url, fit: BoxFit.cover,
                       cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 2048),''', 'imagem de capa')

# Somente gravar apos TODAS as verificacoes passarem.
s = marker + '\n' + s
p.write_text(s, encoding='utf-8')
print('Velora: responsividade e acessibilidade basica aplicadas com sucesso.')
PY
