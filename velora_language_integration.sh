#!/usr/bin/env bash
set -euo pipefail

# Velora - integracao inicial segura de idiomas.
# Executar DEPOIS de velora_language_upgrade.sh e dos scripts que geram as telas.
# Este passo conecta a preferencia persistida e um seletor de idiomas ao perfil.
# A traducao de cada texto das telas sera feita em uma etapa separada.

python3 - <<'PY'
from pathlib import Path
import re

main = Path('lib/main.dart')
if not main.exists():
    raise SystemExit('ERRO: lib/main.dart nao encontrado.')

candidates = list(Path('lib').rglob('*.dart'))
lang_files = [p for p in candidates if 'class VeloraLanguageStore' in p.read_text(encoding='utf-8')]
if len(lang_files) != 1:
    raise SystemExit(f'ERRO: esperado 1 arquivo VeloraLanguageStore; encontrados {len(lang_files)}.')
lang = lang_files[0]
lang_import = lang.relative_to(Path('lib')).as_posix()

s = main.read_text(encoding='utf-8')
import_line = f"import '{lang_import}';"
if import_line not in s:
    m = re.search(r"^import ['\"]package:flutter/material\.dart['\"];\s*$", s, re.M)
    if not m:
        raise SystemExit('ERRO: import material.dart nao localizado. main.dart preservado.')
    s = s[:m.end()] + '\n' + import_line + s[m.end():]

# O carregamento deve ocorrer antes da inicializacao visual, depois do binding.
if 'await VeloraLanguageStore.load();' not in s:
    anchor = 'WidgetsFlutterBinding.ensureInitialized();'
    if anchor not in s:
        raise SystemExit('ERRO: WidgetsFlutterBinding nao localizado. main.dart preservado.')
    s = s.replace(anchor, anchor + '\n  await VeloraLanguageStore.load();', 1)

# A raiz escuta alteracoes e redesenha as telas ao trocar o idioma.
old = 'runApp(const MiniSeriesApp());'
new = '''runApp(ValueListenableBuilder<VeloraLanguage>(
    valueListenable: VeloraLanguageStore.current,
    builder: (context, language, child) => MiniSeriesApp(key: ValueKey(language.code)),
  ));'''
if old in s:
    s = s.replace(old, new, 1)
elif 'valueListenable: VeloraLanguageStore.current' not in s:
    raise SystemExit('ERRO: runApp principal nao reconhecido. main.dart preservado.')

# O widget seletor fica separado para nao depender da implementacao do perfil.
selector = Path('lib/velora_language_selector.dart')
selector.write_text('''import 'package:flutter/material.dart';
import '%s';

class VeloraLanguageSelector extends StatelessWidget {
  const VeloraLanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VeloraLanguage>(
      valueListenable: VeloraLanguageStore.current,
      builder: (context, selected, _) => ListTile(
        leading: const Icon(Icons.language),
        title: Text(VeloraText.get('language')),
        trailing: DropdownButton<VeloraLanguage>(
          value: selected,
          underline: const SizedBox.shrink(),
          items: VeloraLanguage.values.map((language) => DropdownMenuItem(
            value: language,
            child: Text(switch (language) {
              VeloraLanguage.ptBR => 'Português',
              VeloraLanguage.en => 'English',
              VeloraLanguage.es => 'Español',
            }),
          )).toList(),
          onChanged: (language) async {
            if (language == null) return;
            try {
              await VeloraLanguageStore.select(language);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Não foi possível salvar o idioma.')),
                );
              }
            }
          },
        ),
      ),
    );
  }
}
''' % lang_import, encoding='utf-8')

# Encontra o arquivo real do perfil e injeta o seletor antes da opcao de sair.
profile_files = []
for p in Path('lib').rglob('*.dart'):
    if p in (main, lang, selector):
        continue
    content = p.read_text(encoding='utf-8')
    if "Text('Sair da conta')" in content or 'Text("Sair da conta")' in content:
        profile_files.append(p)

if len(profile_files) != 1:
    raise SystemExit(f'ERRO: tela de perfil nao identificada com seguranca ({len(profile_files)} candidatas). Nenhuma tela foi alterada.')
profile = profile_files[0]
p = profile.read_text(encoding='utf-8')
relative = __import__('os').path.relpath(selector, profile.parent).replace('\\', '/')
selector_import = f"import '{relative}';"
if selector_import not in p:
    match = re.search(r"^import [^\n]+;\s*$", p, re.M)
    if not match:
        raise SystemExit('ERRO: imports do perfil nao encontrados.')
    p = p[:match.end()] + '\n' + selector_import + p[match.end():]

# Localiza o cartao de sair a partir do texto visivel, mesmo que outros
# scripts tenham alterado espacamento, parametros ou incluido novos cartoes.
if 'const VeloraLanguageSelector()' not in p:
    logout = re.search(r"title\s*:\s*(?:const\s+)?Text\(\s*['\"]Sair da conta['\"]", p)
    if not logout:
        raise SystemExit('ERRO: texto de sair da conta nao localizado. Tela preservada.')
    prefix = p[:logout.start()]
    # A tela original usa Card(... child: ListTile(... title: Text(...)).
    cards = list(re.finditer(r"(?m)^[ \t]*Card\s*\(", prefix))
    if not cards:
        raise SystemExit('ERRO: cartao de sair nao localizado. Tela preservada.')
    card = cards[-1]
    between = p[card.end():logout.start()]
    if 'ListTile' not in between or len(between) > 1600:
        raise SystemExit('ERRO: estrutura do cartao de sair inesperada. Tela preservada.')
    line_start = p.rfind('\n', 0, card.start()) + 1
    indent = re.match(r'[ \t]*', p[line_start:]).group(0)
    p = p[:line_start] + indent + 'const VeloraLanguageSelector(),\n' + p[line_start:]

main.write_text(s, encoding='utf-8')
profile.write_text(p, encoding='utf-8')
print('OK: idioma salvo carregado antes do app iniciar.')
print('OK: raiz do app reconstruida quando o idioma muda.')
print(f'OK: seletor de idioma inserido em {profile}.')
print('ATENCAO: textos fixos das demais telas ainda precisam ser traduzidos.')
PY
