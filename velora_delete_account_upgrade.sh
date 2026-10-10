#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
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
          const Text('Esta ação é permanente. Sua conta será excluída e você perderá o acesso ao Velora. Digite EXCLUIR para confirmar.'),
          const SizedBox(height: 14),
          TextField(controller: confirmation,
            decoration: const InputDecoration(labelText: 'Digite EXCLUIR'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(dialogContext,
            confirmation.text.trim() == 'EXCLUIR'),
            child: const Text('Confirmar exclusão')),
        ],
      ),
    );
    confirmation.dispose();
    if (approved != true || !mounted) return;
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Sessão expirada. Entre novamente.');
     final response = await Supabase.instance.client.functions.invoke(
  'delete-account',
  headers: {'Authorization': 'Bearer ${session.accessToken}'},
  body: {
    'confirmation': 'EXCLUIR MINHA CONTA',
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
assert s.count(old)==1, 'Não encontrei o texto antigo de exclusão no perfil'
s=s.replace(old,new)
p.write_text(s)
print('Página Perfil atualizada com botão de exclusão e confirmação.')
PY
