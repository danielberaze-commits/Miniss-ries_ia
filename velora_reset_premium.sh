#!/usr/bin/env bash
set -euo pipefail
mkdir -p lib/screens
cat > lib/screens/reset_password_screen.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _background = Color(0xFF0B0911);
const _purple = Color(0xFF8238D6);
const _gold = Color(0xFFEAC08A);
const _muted = Color(0xFFB8AEC2);

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.onFinished});
  final VoidCallback? onFinished;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool loading = false;
  bool showPassword = false;
  bool showConfirm = false;

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> savePassword() async {
    if (loading || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => loading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: passwordController.text),
      );
      if (!mounted) return;
      _message('Senha atualizada com sucesso!');
      widget.onFinished?.call();
    } catch (error) {
      if (!mounted) return;
      _message('Não foi possível atualizar a senha. Tente novamente.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  InputDecoration _decoration(String label, bool visible, VoidCallback toggle) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted),
      prefixIcon: const Icon(Icons.lock_outline, color: _gold),
      suffixIcon: IconButton(
        tooltip: visible ? 'Ocultar senha' : 'Mostrar senha',
        onPressed: toggle,
        icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _gold),
      ),
      filled: true,
      fillColor: const Color(0xFF1C1728),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF352A47))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _purple, width: 1.7)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF8A8A))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(primary: _purple, surface: _background),
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF21102F), _background, Color(0xFF100B19)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_circle_fill_rounded, size: 72, color: _gold),
                        const SizedBox(height: 12),
                        const Text('VELORA', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700,
                              letterSpacing: 5, color: _gold)),
                        const SizedBox(height: 9),
                        const Text('MINISSÉRIES QUE TE LEVAM MAIS LONGE',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9, letterSpacing: 2.1, color: _muted)),
                        const SizedBox(height: 42),
                        const Text('Crie sua nova senha',
                          style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold,
                              color: Colors.white)),
                        const SizedBox(height: 9),
                        const Text('Escolha uma senha segura para continuar sua jornada.',
                          style: TextStyle(color: _muted, fontSize: 14)),
                        const SizedBox(height: 26),
                        TextFormField(
                          controller: passwordController,
                          obscureText: !showPassword,
                          style: const TextStyle(color: Colors.white),
                          textInputAction: TextInputAction.next,
                          decoration: _decoration('Nova senha', showPassword,
                            () => setState(() => showPassword = !showPassword)),
                          validator: (value) => (value ?? '').length < 6
                              ? 'Use pelo menos 6 caracteres.' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: confirmController,
                          obscureText: !showConfirm,
                          style: const TextStyle(color: Colors.white),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => savePassword(),
                          decoration: _decoration('Confirmar senha', showConfirm,
                            () => setState(() => showConfirm = !showConfirm)),
                          validator: (value) => value != passwordController.text
                              ? 'As senhas não coincidem.' : null,
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: loading ? null : savePassword,
                            style: FilledButton.styleFrom(
                              backgroundColor: _purple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            ),
                            child: loading
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                              : const Text('Salvar nova senha',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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
