#!/usr/bin/env bash
set -euo pipefail
# Velora: execute depois de velora_home_translation.sh e velora_delete_account_upgrade.sh.
python3 - <<'PY'
from pathlib import Path
import re
p = Path('lib/screens/home_screen.dart')
if not p.exists():
    raise SystemExit('ERRO: home_screen.dart não encontrado')
s = p.read_text(encoding='utf-8')
if '_veloraTr(' not in s or 'VeloraLanguageStore' not in s:
    raise SystemExit('ERRO: execute velora_home_translation.sh antes deste script')
if 'Future<void> _deleteAccount()' not in s:
    raise SystemExit('ERRO: execute velora_delete_account_upgrade.sh antes deste script')
# Apenas textos de interface. Valores de confirmação enviados ao backend não mudam.
translations = {
    'Excluir minha conta': ('Delete my account', 'Eliminar mi cuenta'),
    'Exclusão permanente': ('Permanent deletion', 'Eliminación permanente'),
    'Esta ação é permanente. Sua conta será excluída e você perderá o acesso ao Velora. Digite EXCLUIR para confirmar.': (
        'This action is permanent. Your account will be deleted and you will lose access to Velora. Type EXCLUIR to confirm.',
        'Esta acción es permanente. Tu cuenta será eliminada y perderás el acceso a Velora. Escribe EXCLUIR para confirmar.'),
    'Digite EXCLUIR': ('Type EXCLUIR', 'Escribe EXCLUIR'),
    'Cancelar': ('Cancel', 'Cancelar'),
    'Confirmar exclusão': ('Confirm deletion', 'Confirmar eliminación'),
    'Código de segurança': ('Security code', 'Código de seguridad'),
    'Código recebido por e-mail': ('Code received by email', 'Código recibido por correo'),
    'Verificar e excluir': ('Verify and delete', 'Verificar y eliminar'),
}
# Substituições específicas, com proteção para evitar alterações em lógica de segurança.
for pt, (en, es) in translations.items():
    expr = f'_veloraTr({pt!r}, {en!r}, {es!r})'
    # Text(...) e Text('...') em títulos, mensagens e botões.
    pattern = r'\b(const\s+)?Text\(\s*' + re.escape(repr(pt)) + r'(?=\s*[,\)])'
    s = re.sub(pattern, lambda m: 'Text(' + expr, s)
    # labelText em InputDecoration, que deixa de ser const.
    if pt == 'Digite EXCLUIR' or pt == 'Código recebido por e-mail':
        pattern = r'labelText:\s*' + re.escape(repr(pt))
        s = re.sub(pattern, lambda m: 'labelText: ' + expr, s)
# Interpolação de email precisa permanecer dinâmica.
email_pt = 'Enviamos um código para $email. Digite o código para confirmar a exclusão.'
email_en = 'We sent a code to $email. Enter it to confirm account deletion.'
email_es = 'Enviamos un código a $email. Introdúcelo para confirmar la eliminación.'
if email_pt in s:
    s = s.replace('''Text(\n  'Enviamos um código para $email. Digite o código para confirmar a exclusão.', ''', '''Text(\n  _veloraTr('Enviamos um código para $email. Digite o código para confirmar a exclusão.', 'We sent a code to $email. Enter it to confirm account deletion.', 'Enviamos un código a $email. Introdúcelo para confirmar la eliminación.'), ''')
    # Fallback if original formatting differs
    if email_pt in s and "_veloraTr('Enviamos um código" not in s:
        s = s.replace("'" + email_pt + "'", f"_veloraTr({email_pt!r}, {email_en!r}, {email_es!r})")
# Mensagem de erro sem alterar interpolação do erro.
error_pt = 'Não foi possível excluir a conta: $error'
if error_pt in s:
    s = s.replace("'" + error_pt + "'", "_veloraTr('Não foi possível excluir a conta: $error', 'Could not delete account: $error', 'No se pudo eliminar la cuenta: $error')")
# Remover const somente de ancestrais diretos que agora contêm expressões dinâmicas.
# As janelas são criadas com builder e suas propriedades podem receber expressões.
s = s.replace("decoration: const InputDecoration(\n    labelText: _veloraTr(", "decoration: InputDecoration(\n    labelText: _veloraTr(")
# Em um InputDecoration não-const, os estilos internos continuam const.
# Certificar que as traduções foram aplicadas nos itens principais.
if "title: Text(_veloraTr('Excluir minha conta'" not in s:
    raise SystemExit('ERRO: título de exclusão não encontrado; arquivo original preservado')
if "subtitle: Text(_veloraTr('Exclusão permanente'" not in s:
    raise SystemExit('ERRO: subtítulo de exclusão não encontrado; arquivo original preservado')
p.write_text(s, encoding='utf-8')
print('OK: textos de exclusão traduzidos. Confirmações de segurança preservadas.')
PY
