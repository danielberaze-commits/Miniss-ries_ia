#!/usr/bin/env bash
set -euo pipefail
# Execute apos todos os scripts que alteram a tela de idiomas, antes do flutter pub get.
python3 - <<'PY'
from pathlib import Path
p = Path('lib/velora_language_selector.dart')
if not p.is_file():
    raise SystemExit('ERRO: tela de idiomas nao encontrada; nada alterado.')
s = p.read_text(encoding='utf-8')
marker = '// VELORA_IDIOMAS_RESPONSIVO_V1'
if marker in s:
    print('OK: ajuste de idiomas ja aplicado.')
    raise SystemExit(0)

def change(old, new, name):
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'ERRO: {name}: encontrado {count} vez(es), esperado 1. Arquivo preservado.')
    s = s.replace(old, new, 1)

change('''      body: SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [''', '''      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) =>
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(mainAxisSize: MainAxisSize.min, children: [''', 'inicio do corpo rolavel')
change('''          const Spacer(),
          SizedBox(width: double.infinity, height: 52,
            child: FilledButton(''', '''          const Spacer(),
          SizedBox(width: double.infinity,
            child: FilledButton(''', 'botao com altura fixa')
change('''                backgroundColor: const Color(0xFF8B2BEE),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),''', '''                backgroundColor: const Color(0xFF8B2BEE),
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),''', 'botao adaptavel')
change('''          const SizedBox(height: 20),
        ]),
      )),
    );''', '''          const SizedBox(height: 20),
                ]),
              ),
            ),
          ),
        ),
      ),
    );''', 'fim do corpo rolavel')
# Evita quebra desnecessaria de nomes quando a fonte e ampliada.
change('''              const SizedBox(width: 16),
              Expanded(child: Column(''', '''              const SizedBox(width: 10),
              Expanded(child: Column(''', 'espacamento de opcoes')
# Escrita atomica somente apos todas as verificacoes.
tmp = p.with_suffix('.dart.velora_tmp')
tmp.write_text(marker + '\n' + s, encoding='utf-8')
tmp.replace(p)
print('OK: tela de idiomas com rolagem e botao adaptavel.')
PY
