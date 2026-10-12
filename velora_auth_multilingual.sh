#!/usr/bin/env bash
set -euo pipefail
# Velora: executar depois dos scripts de login, reset e idiomas.
python3 - <<'PY'
from pathlib import Path
p = Path('lib/screens/auth_screen.dart')
if not p.exists():
    raise SystemExit('ERRO: lib/screens/auth_screen.dart nao existe.')
s = p.read_text(encoding='utf-8')
if 'VELORA_AUTH_I18N_V1' in s:
    print('Autenticacao multilingue ja aplicada.')
    raise SystemExit(0)
if not Path('lib/l10n/velora_language.dart').exists():
    raise SystemExit('ERRO: execute velora_language_upgrade.sh primeiro.')

def replace(old, new):
    global s
    count=s.count(old)
    if count != 1:
        raise SystemExit(f'ERRO: trecho esperado encontrado {count} vezes: {old[:85]!r}. Nenhuma alteracao foi salva.')
    s=s.replace(old,new,1)

replace("import 'package:supabase_flutter/supabase_flutter.dart';", "import 'package:supabase_flutter/supabase_flutter.dart';\nimport '../l10n/velora_language.dart'; // VELORA_AUTH_I18N_V1")
replace('class _AuthScreenState extends State<AuthScreen> {', '''class _AuthScreenState extends State<AuthScreen> {
  static const _translations = <String, List<String>>{
    'tagline': ['MINISSÉRIES QUE TE LEVAM MAIS LONGE', 'SHORT SERIES THAT TAKE YOU FURTHER', 'MINISERIES QUE TE LLEVAN MÁS LEJOS'],
    'welcome': ['Bem-vindo ao Velora', 'Welcome to Velora', 'Bienvenido a Velora'],
    'signup_title': ['Crie sua conta', 'Create your account', 'Crea tu cuenta'],
    'login_subtitle': ['Entre e descubra histórias extraordinárias.', 'Sign in and discover extraordinary stories.', 'Inicia sesión y descubre historias extraordinarias.'],
    'signup_subtitle': ['Sua próxima história começa aqui.', 'Your next story starts here.', 'Tu próxima historia comienza aquí.'],
    'email': ['E-mail', 'Email', 'Correo electrónico'],
    'password': ['Senha', 'Password', 'Contraseña'],
    'forgot': ['Esqueceu sua senha?', 'Forgot your password?', '¿Olvidaste tu contraseña?'],
    'create': ['CRIAR CONTA', 'CREATE ACCOUNT', 'CREAR CUENTA'],
    'signin': ['ENTRAR', 'SIGN IN', 'INICIAR SESIÓN'],
    'google': ['Continuar com Google', 'Continue with Google', 'Continuar con Google'],
    'has_account': ['Já tem uma conta? Entrar', 'Already have an account? Sign in', '¿Ya tienes una cuenta? Inicia sesión'],
    'no_account': ['Não tem uma conta? Cadastre-se', 'Don’t have an account? Sign up', '¿No tienes cuenta? Regístrate'],
    'invalid': ['Informe um e-mail válido e uma senha de pelo menos 6 caracteres.', 'Enter a valid email and a password of at least 6 characters.', 'Introduce un correo válido y una contraseña de al menos 6 caracteres.'],
    'confirm': ['Cadastro enviado! Confirme seu e-mail para entrar.', 'Registration sent! Confirm your email to sign in.', '¡Registro enviado! Confirma tu correo para iniciar sesión.'],
    'created': ['Conta criada com sucesso!', 'Account created successfully!', '¡Cuenta creada correctamente!'],
    'generic': ['Não foi possível continuar. Tente novamente.', 'Could not continue. Please try again.', 'No se pudo continuar. Inténtalo de nuevo.'],
    'google_error': ['Não foi possível iniciar o acesso pelo Google.', 'Could not start Google sign-in.', 'No se pudo iniciar sesión con Google.'],
    'reset_email': ['Digite seu e-mail no campo acima para recuperar a senha.', 'Enter your email above to reset your password.', 'Introduce tu correo arriba para recuperar tu contraseña.'],
    'reset_sent': ['Se o e-mail estiver cadastrado, você receberá um link de recuperação.', 'If the email is registered, you will receive a recovery link.', 'Si el correo está registrado, recibirás un enlace de recuperación.'],
    'reset_error': ['Não foi possível solicitar a recuperação.', 'Could not request password recovery.', 'No se pudo solicitar la recuperación.'],
  };

  String _tr(String key) {
    final language = VeloraLanguageStore.current.value;
    final index = language == VeloraLanguage.en ? 1 : (language == VeloraLanguage.es ? 2 : 0);
    return _translations[key]![index];
  }

  Widget _languagePicker() => ValueListenableBuilder<VeloraLanguage>(
    valueListenable: VeloraLanguageStore.current,
    builder: (context, selected, _) => Align(
      alignment: Alignment.centerRight,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<VeloraLanguage>(
          value: selected,
          dropdownColor: const Color(0xFF17111F),
          iconEnabledColor: _gold,
          style: const TextStyle(color: _gold, fontSize: 13),
          items: const [
            DropdownMenuItem(value: VeloraLanguage.ptBR, child: Text('🇧🇷 Português')),
            DropdownMenuItem(value: VeloraLanguage.en, child: Text('🇺🇸 English')),
            DropdownMenuItem(value: VeloraLanguage.es, child: Text('🇪🇸 Español')),
          ],
          onChanged: _loading ? null : (language) async {
            if (language == null) return;
            try {
              await VeloraLanguageStore.select(language);
            } catch (_) {
              _message(_tr('generic'));
            }
          },
        ),
      ),
    ),
  );
''')
# Translate only exact string expressions, leaving Supabase auth untouched.
for original, key in [
 ('Informe um e-mail válido e uma senha de pelo menos 6 caracteres.', 'invalid'),
 ('Não foi possível continuar. Tente novamente.', 'generic'),
 ('Não foi possível iniciar o acesso pelo Google.', 'google_error'),
 ('Digite seu e-mail no campo acima para recuperar a senha.', 'reset_email'),
 ('Se o e-mail estiver cadastrado, você receberá um link de recuperação.', 'reset_sent'),
 ('Não foi possível solicitar a recuperação.', 'reset_error'),
]:
    # match usage in _message only, not the translation table
    replace("_message('"+original+"');", "_message(_tr('"+key+"'));")
replace("? 'Cadastro enviado! Confirme seu e-mail para entrar.'\n            : 'Conta criada com sucesso!'", "? _tr('confirm')\n            : _tr('created')")
replace('    return Scaffold(\n      backgroundColor:', '''    return ValueListenableBuilder<VeloraLanguage>(
      valueListenable: VeloraLanguageStore.current,
      builder: (context, language, _) => Scaffold(
      backgroundColor:''')
replace('''      ),
    );
  }
}
''', '''      ),
    ));
  }
}
''')
replace("children: [\n                      Image.asset('assets/velora_login_logo.png',", "children: [\n                      _languagePicker(),\n                      Image.asset('assets/velora_login_logo.png',")
replace("const Text(\n                        'MINISSÉRIES QUE TE LEVAM MAIS LONGE',", "Text(\n                        _tr('tagline'),")
replace("_signUp ? 'Crie sua conta' : 'Bem-vindo ao Velora'", "_signUp ? _tr('signup_title') : _tr('welcome')")
replace("? 'Sua próxima história começa aqui.'\n                            : 'Entre e descubra histórias extraordinárias.'", "? _tr('signup_subtitle')\n                            : _tr('login_subtitle')")
replace("_decoration('E-mail', Icons.alternate_email)", "_decoration(_tr('email'), Icons.alternate_email)")
replace("_decoration('Senha', Icons.lock_outline)", "_decoration(_tr('password'), Icons.lock_outline)")
replace("child: const Text('Esqueceu sua senha?',\n                                style: TextStyle(color: _gold))", "child: Text(_tr('forgot'),\n                                style: const TextStyle(color: _gold))")
replace("_signUp ? 'CRIAR CONTA' : 'ENTRAR'", "_signUp ? _tr('create') : _tr('signin')")
replace("label: const Text('Continuar com Google')", "label: Text(_tr('google'))")
replace("_signUp ? 'Já tem uma conta? Entrar' : 'Não tem uma conta? Cadastre-se'", "_signUp ? _tr('has_account') : _tr('no_account')")
p.write_text(s, encoding='utf-8')
print('Login Velora: traducoes e seletor de idioma aplicados.')
PY
