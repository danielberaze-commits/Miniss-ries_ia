#!/usr/bin/env bash
set -euo pipefail

# Execute depois de setup.sh e auth_upgrade.sh.
# Envie velora_login_logo.png e velora_login_bg.png para a raiz do repositorio.
for arquivo in velora_login_logo.png velora_login_bg.png; do
  test -f "$arquivo" || { echo "ERRO: falta $arquivo na raiz do repositorio."; exit 1; }
done
mkdir -p assets lib/screens
cp velora_login_logo.png assets/velora_login_logo.png
cp velora_login_bg.png assets/velora_login_bg.png

python3 - <<'PY'
from pathlib import Path
p=Path('pubspec.yaml')
s=p.read_text()
if '\nflutter:\n' not in s:
    raise RuntimeError('Bloco flutter: nao encontrado em pubspec.yaml')
if '  assets:\n' in s:
    for name in ('velora_login_logo.png','velora_login_bg.png'):
        if 'assets/'+name not in s:
            s=s.replace('  assets:\n', '  assets:\n    - assets/'+name+'\n', 1)
else:
    s=s.replace('\nflutter:\n', '\nflutter:\n  assets:\n    - assets/velora_login_logo.png\n    - assets/velora_login_bg.png\n', 1)
p.write_text(s)
PY

cat > lib/screens/auth_screen.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _gold = Color(0xFFE8BE80);
const _purple = Color(0xFF9E4AE4);
const _surface = Color(0xFF17111F);
const _loginRedirect = 'miniseriesia://login-callback/';
const _recoveryRedirect = 'miniseriesia://reset-callback/';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@') || password.length < 6) {
      _message('Informe um e-mail válido e uma senha de pelo menos 6 caracteres.');
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (_signUp) {
        final response = await auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: _loginRedirect,
        );
        if (!mounted) return;
        _message(response.session == null
            ? 'Cadastro enviado! Confirme seu e-mail para entrar.'
            : 'Conta criada com sucesso!');
        if (response.session == null) setState(() => _signUp = false);
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (e) {
      _message(e.message);
    } catch (_) {
      _message('Não foi possível continuar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _loginRedirect,
      );
    } on AuthException catch (e) {
      _message(e.message);
    } catch (_) {
      _message('Não foi possível iniciar o acesso pelo Google.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _message('Digite seu e-mail no campo acima para recuperar a senha.');
      return;
    }
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: _recoveryRedirect,
      );
      _message('Se o e-mail estiver cadastrado, você receberá um link de recuperação.');
    } on AuthException catch (e) {
      _message(e.message);
    } catch (_) {
      _message('Não foi possível solicitar a recuperação.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFB8A8BE)),
        prefixIcon: Icon(icon, color: _gold, size: 21),
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 19, horizontal: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF47324F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _purple, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08060B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/velora_login_bg.png', fit: BoxFit.cover),
          Container(color: const Color(0x77060010)),
          SafeArea(child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/velora_login_logo.png',
                          height: 205, fit: BoxFit.contain),
                      const SizedBox(height: 4),
                      const Text(
                        'MINISSÉRIES QUE TE LEVAM MAIS LONGE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFD2B98F),
                          fontSize: 10,
                          letterSpacing: 2.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        _signUp ? 'Crie sua conta' : 'Bem-vindo ao Velora',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFF7EBE3),
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _signUp
                            ? 'Sua próxima história começa aqui.'
                            : 'Entre e descubra histórias extraordinárias.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB4A4BA), fontSize: 13),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration('E-mail', Icons.alternate_email),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: !_showPassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration('Senha', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFFB8A8BE),
                            ),
                          ),
                        ),
                      ),
                      if (!_signUp)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _reset,
                            child: const Text('Esqueceu sua senha?',
                                style: TextStyle(color: _gold)),
                          ),
                        )
                      else
                        const SizedBox(height: 19),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: const Color(0xFF1A1018),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_signUp ? 'CRIAR CONTA' : 'ENTRAR',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _google,
                          icon: const Icon(Icons.g_mobiledata, size: 28, color: _gold),
                          label: const Text('Continuar com Google'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF644675)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 17),
                      TextButton(
                        onPressed: _loading ? null : () => setState(() => _signUp = !_signUp),
                        child: Text(
                          _signUp ? 'Já tem uma conta? Entrar' : 'Não tem uma conta? Cadastre-se',
                          style: const TextStyle(color: _gold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )),
          ],
      ),
    );
  }
}
DART

echo 'Tela de login Velora instalada.'
