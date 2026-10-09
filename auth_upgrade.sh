#!/usr/bin/env bash
set -euo pipefail

# Execute after: flutter create . && bash setup.sh
mkdir -p lib/screens

cat > lib/main.dart <<'DART'
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reset_password_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isEmpty || key.isEmpty) {
    runApp(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Supabase não configurado.'))),
    ));
    return;
  }
  await Supabase.initialize(
  url: url,
  anonKey: key,
  authOptions: const FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce,
  ),
);
  runApp(const MiniSeriesApp());
}

class MiniSeriesApp extends StatefulWidget {
  const MiniSeriesApp({super.key});

  @override
  State<MiniSeriesApp> createState() => _MiniSeriesAppState();
}

class _MiniSeriesAppState extends State<MiniSeriesApp> {
  StreamSubscription<AuthState>? _subscription;
  bool _passwordRecovery = false;

  @override
  void initState() {
    super.initState();
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      setState(() {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          _passwordRecovery = true;
        } else if (data.event == AuthChangeEvent.signedOut) {
          _passwordRecovery = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return MaterialApp(
      title: 'MiniSéries IA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7956D8)),
        useMaterial3: true,
      ),
      home: _passwordRecovery
    ? ResetPasswordScreen(
        onFinished: () {
          if (mounted) {
            setState(() => _passwordRecovery = false);
          }
        },
      )
    : session == null
        ? const AuthScreen()
        : const HomeScreen(),
    );
  }
}
DART

cat > lib/screens/auth_screen.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const authRedirect = 'miniseriesia://login-callback/';
const recoveryRedirect = 'miniseriesia://reset-callback/';
const _bg = Color(0xFF0C0B16);
const _purple = Color(0xFF926AFF);
const _muted = Color(0xFFB8B4CC);

String friendlyAuthError(Object error) {
  final message = error is AuthException ? error.message : error.toString();
  final value = message.toLowerCase();
  if (value.contains('invalid login credentials') ||
      value.contains('invalid_credentials')) {
    return 'E-mail ou senha incorretos.';
  }
  if (value.contains('email not confirmed')) {
    return 'Confirme seu e-mail antes de entrar.';
  }
  if (value.contains('already registered') || value.contains('already exists')) {
    return 'Este e-mail já está cadastrado.';
  }
  if (value.contains('password should be') || value.contains('weak_password')) {
    return 'Escolha uma senha mais forte.';
  }
  if (value.contains('rate limit') || value.contains('over_email_send_rate_limit')) {
    return 'Muitas tentativas. Aguarde alguns minutos.';
  }
  if (value.contains('provider is not enabled') ||
      value.contains('unsupported provider')) {
    return 'O login pelo Google ainda precisa ser ativado no Supabase.';
  }
  if (value.contains('socketexception') || value.contains('failed host lookup')) {
    return 'Não foi possível conectar. Verifique sua internet.';
  }
  return message;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _signup = false;
  bool _loading = false;
  bool _showPass = false;
  bool _showConfirm = false;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _switchMode(bool signup) {
    setState(() {
      _signup = signup;
      _notice = null;
      _showPass = false;
      _showConfirm = false;
      _formKey.currentState?.reset();
      _password.clear();
      _confirm.clear();
    });
  }

  String? _emailValidator(String? value) {
    final email = (value ?? '').trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_loading || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _notice = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_signup) {
        final result = await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {'full_name': _name.text.trim()},
          emailRedirectTo: authRedirect,
        );
        if (!mounted) return;
        if (result.session == null) {
          setState(() {
            _notice = 'Cadastro solicitado! Confira sua caixa de entrada e '
                'confirme seu e-mail para começar a assistir.';
          });
        } else {
          _message('Sua conta foi criada! Bem-vindo(a).');
        }
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      // The root widget listens to auth state and opens HomeScreen.
    } catch (error) {
      _message(friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final opened = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: authRedirect,
      );
      if (!opened) _message('Não foi possível abrir o Google. Tente novamente.');
    } catch (error) {
      _message(friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (_emailValidator(email) != null) {
      _message('Digite seu e-mail no campo acima para recuperar a senha.');
      return;
    }
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: recoveryRedirect,
      );
      _message('Se o e-mail estiver cadastrado, você receberá um link de recuperação.');
    } catch (error) {
      _message(friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted),
      prefixIcon: Icon(icon, color: _muted),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF1C1A2D),
      contentPadding: const EdgeInsets.symmetric(vertical: 19, horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _purple, width: 1.5),
      ),
    );
  }

  Widget _passwordField({required TextEditingController controller,
      required String label, required bool show, required VoidCallback toggle,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      validator: validator,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(
        label,
        Icons.lock_outline,
        suffix: IconButton(
          tooltip: show ? 'Ocultar senha' : 'Mostrar senha',
          onPressed: toggle,
          icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _muted),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: const ColorScheme.dark(primary: _purple, surface: _bg),
      scaffoldBackgroundColor: _bg,
    );
    return Theme(
      data: theme,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF23153B), _bg, Color(0xFF100E1D)],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 26),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 15),
                            Center(
                              child: Container(
                                height: 82,
                                width: 82,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: const LinearGradient(
                                    colors: [_purple, Color(0xFF4F2BBD)],
                                  ),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x556743D7),
                                        blurRadius: 32, offset: Offset(0, 14)),
                                  ],
                                ),
                                child: const Icon(Icons.play_arrow_rounded,
                                    size: 52, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text('MiniSéries IA',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
                                  letterSpacing: -.7, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            const Text('Suas histórias favoritas começam aqui.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _muted, fontSize: 14),
                            ),
                            const SizedBox(height: 35),
                            Text(_signup ? 'Crie sua conta' : 'Bem-vindo de volta',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 7),
                            Text(_signup
                                ? 'Cadastre-se para assistir às minisséries.'
                                : 'Entre na sua conta para continuar assistindo.',
                              style: const TextStyle(color: _muted),
                            ),
                            const SizedBox(height: 22),
                            if (_signup) ...[
                              TextFormField(
                                controller: _name,
                                style: const TextStyle(color: Colors.white),
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: _decoration('Seu nome', Icons.person_outline),
                                validator: (value) => (value ?? '').trim().length < 2
                                    ? 'Digite seu nome.' : null,
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: _email,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              validator: _emailValidator,
                              decoration: _decoration('E-mail', Icons.alternate_email),
                            ),
                            const SizedBox(height: 14),
                            _passwordField(
                              controller: _password, label: 'Senha', show: _showPass,
                              toggle: () => setState(() => _showPass = !_showPass),
                              validator: (value) => (value ?? '').length < 6
                                  ? 'A senha precisa ter pelo menos 6 caracteres.' : null,
                            ),
                            if (_signup) ...[
                              const SizedBox(height: 14),
                              _passwordField(
                                controller: _confirm,
                                label: 'Confirmar senha',
                                show: _showConfirm,
                                toggle: () => setState(() => _showConfirm = !_showConfirm),
                                validator: (value) => value != _password.text
                                    ? 'As senhas não coincidem.' : null,
                              ),
                            ],
                            if (!_signup)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _loading ? null : _forgotPassword,
                                  child: const Text('Esqueci minha senha',
                                      style: TextStyle(color: Color(0xFFBDA5FF))),
                                ),
                              ),
                            if (_signup) const SizedBox(height: 20),
                            if (_notice != null) ...[
                              Container(
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF24392F),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(_notice!,
                                    style: const TextStyle(color: Color(0xFFCDF5D8))),
                              ),
                              const SizedBox(height: 16),
                            ],
                            SizedBox(
                              height: 54,
                              child: FilledButton(
                                onPressed: _loading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _purple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _loading
                                    ? const SizedBox(width: 22, height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2,
                                            color: Colors.white))
                                    : Text(_signup ? 'Criar minha conta' : 'Entrar',
                                        style: const TextStyle(fontSize: 16,
                                            fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(height: 17),
                            const Row(children: [
                              Expanded(child: Divider(color: Color(0xFF393347))),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('ou', style: TextStyle(color: _muted))),
                              Expanded(child: Divider(color: Color(0xFF393347))),
                            ]),
                            const SizedBox(height: 17),
                            SizedBox(
                              height: 54,
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _google,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFF49435E)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                icon: const Text('G', style: TextStyle(fontSize: 21,
                                    fontWeight: FontWeight.w900, color: Colors.white)),
                                label: const Text('Continuar com Google'),
                              ),
                            ),
                            const SizedBox(height: 19),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_signup ? 'Já tem conta?' : 'Ainda não tem conta?',
                                    style: const TextStyle(color: _muted)),
                                TextButton(
                                  onPressed: _loading ? null : () => _switchMode(!_signup),
                                  child: Text(_signup ? 'Entrar' : 'Criar conta',
                                    style: const TextStyle(fontWeight: FontWeight.bold,
                                        color: Color(0xFFCBB8FF))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
DART

cat > lib/screens/reset_password_screen.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
  super.key,
  this.onFinished,
});

final VoidCallback? onFinished;
  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool loading = false;

  Future<void> savePassword() async {
    final password = passwordController.text;
    if (password.length < 6 ||
        password != confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use pelo menos 6 caracteres e confirme a senha.',
          ),
        ),
      );
      return;
    }

    setState(() => loading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha atualizada!')),
      );
      widget.onFinished?.call();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $error')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova senha')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nova senha',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar senha',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: loading ? null : savePassword,
              child: Text(
                loading ? 'Salvando...' : 'Salvar nova senha',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
DART


