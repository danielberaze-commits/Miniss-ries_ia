#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
import re
p=Path('lib/screens/home_screen.dart')
s=p.read_text()
needle='  Widget _profile() {'
assert s.count(needle)==1, 'Não encontrei o método _profile no home_screen.dart'
method='''  Future<void> _deleteAccount() async {
    final confirmation = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Excluir minha conta', style: TextStyle(color: _gold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
         const Text(
  'Esta ação é permanente. Sua conta será excluída e você perderá o acesso ao Velora. Digite EXCLUIR para confirmar.',
  style: TextStyle(
    color: Color(0xFFF5F1FA),
    fontSize: 15,
  ),
),
          const SizedBox(height: 14),
          TextField(
  controller: confirmation,
  style: const TextStyle(color: Color(0xFFFFFFFF)),
  cursorColor: const Color(0xFFE8BF82),
  decoration: const InputDecoration(
    labelText: 'Digite EXCLUIR',
    labelStyle: TextStyle(color: Color(0xFFC9C3D3)),
    floatingLabelStyle: TextStyle(color: Color(0xFFE8BF82)),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF8E79B5)),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFE8BF82), width: 2),
    ),
  ),
),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
  'Cancelar',
  style: TextStyle(color: Color(0xFFC9C3D3)),
)),
          TextButton(onPressed: () => Navigator.pop(dialogContext,
            confirmation.text.trim() == 'EXCLUIR'),
           child: const Text(
  'Confirmar exclusão',
  style: TextStyle(
    color: Color(0xFFFF777D),
    fontWeight: FontWeight.bold,
  ),
)),
        ],
      ),
    );
    confirmation.dispose();
    if (approved != true || !mounted) return;
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final email = client.auth.currentUser?.email;
      if (session == null || email == null || email.isEmpty) {
        throw Exception('Sessão expirada ou e-mail não disponível.');
      }
      // O e-mail de código usa o template Magic Link do Supabase.
      // shouldCreateUser: false impede criação de contas nesta etapa.
      await client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
      if (!mounted) return;
      final codeController = TextEditingController();
      final code = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: _surface,
          title: const Text('Código de segurança', style: TextStyle(color: _gold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
           Text(
  'Enviamos um código para $email. Digite o código para confirmar a exclusão.',
  style: const TextStyle(
    color: Color(0xFFF5F1FA),
    fontSize: 15,
  ),
),
            const SizedBox(height: 12),
           TextField(
  controller: codeController,
  keyboardType: TextInputType.number,
  style: const TextStyle(color: Color(0xFFFFFFFF)),
  cursorColor: const Color(0xFFE8BF82),
  decoration: const InputDecoration(
    labelText: 'Código recebido por e-mail',
    labelStyle: TextStyle(color: Color(0xFFC9C3D3)),
    floatingLabelStyle: TextStyle(color: Color(0xFFE8BF82)),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF8E79B5)),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFE8BF82), width: 2),
    ),
  ),
),
            ),
          ]),
          actions: [
            TextButton(
  onPressed: () => Navigator.pop(dialogContext),
  child: const Text(
    'Cancelar',
    style: TextStyle(
      color: Color(0xFFC9C3D3),
      fontWeight: FontWeight.w500,
    ),
  ),
),
TextButton(
  onPressed: () => Navigator.pop(
    dialogContext,
    codeController.text.trim(),
  ),
  child: const Text(
    'Verificar e excluir',
    style: TextStyle(
      color: Color(0xFFFF777D),
      fontWeight: FontWeight.bold,
    ),
  ),
),
          ],
        ),
      );
      codeController.dispose();
      if (code == null || code.isEmpty || !mounted) return;
      final response = await client.functions.invoke(
        'delete-account',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        body: {
          'confirmation': 'EXCLUIR MINHA CONTA',
          'code': code,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        throw Exception('Servidor não concluiu a exclusão: ${response.data}');
      }
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Não foi possível excluir a conta: $error'),
      ));
    }
  }

'''
s=s.replace(needle,method+needle)
old='''       const Text('Gerenciamento e exclusão de conta serão adicionados '
           'em uma próxima etapa, com proteção no servidor.',
           style: TextStyle(color: Color(0xFFBDB5C9), fontSize: 12)),'''
new='''       Card(color: _surface, child: ListTile(
         leading: const Icon(Icons.delete_forever_outlined, color: Color(0xFFFF8A8A)),
         title: const Text('Excluir minha conta'),
         subtitle: const Text('Exclusão permanente'),
         trailing: const Icon(Icons.chevron_right),
         onTap: _deleteAccount,
       )),'''
pattern = r"\s*const Text\('Gerenciamento e exclusão de conta serão adicionados '\s*'em uma próxima etapa, com proteção no servidor\.',\s*style: TextStyle\(color: Color\(0xFFBDB5C9\), fontSize: 12\)\),"
assert len(re.findall(pattern, s)) == 1, 'Não encontrei o texto antigo de exclusão no perfil'
s = re.sub(pattern, '\n'+new, s, count=1)
p.write_text(s)
print('Página Perfil atualizada com botão de exclusão e confirmação.')
PY
