#!/usr/bin/env bash
set -euo pipefail

# Velora — etapa 1: base de internacionalização.
# Executar depois dos scripts que geram o projeto Flutter e antes de flutter pub get/build.
# Esta etapa não altera telas existentes nem a autenticação.

if [[ ! -f pubspec.yaml || ! -d lib ]]; then
  echo 'Erro: execute este script na raiz do projeto Flutter gerado.' >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
p = Path('pubspec.yaml')
s = p.read_text(encoding='utf-8')
if 'shared_preferences:' not in s:
    if 'dependencies:\n' not in s:
        raise SystemExit('Erro: seção dependencies não encontrada em pubspec.yaml')
    s = s.replace('dependencies:\n', 'dependencies:\n  shared_preferences: ^2.3.2\n', 1)
    p.write_text(s, encoding='utf-8')
PY

mkdir -p lib/l10n
cat > lib/l10n/velora_language.dart <<'DART'
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Idiomas de interface oferecidos pelo Velora.
enum VeloraLanguage { ptBR, en, es }

extension VeloraLanguageInfo on VeloraLanguage {
  String get code => switch (this) {
    VeloraLanguage.ptBR => 'pt_BR',
    VeloraLanguage.en => 'en',
    VeloraLanguage.es => 'es',
  };

  String get nativeName => switch (this) {
    VeloraLanguage.ptBR => 'Português (Brasil)',
    VeloraLanguage.en => 'English',
    VeloraLanguage.es => 'Español',
  };
}

/// Estado global leve, a ser ligado ao MaterialApp na etapa de integração.
/// Carregue com `await VeloraLanguageStore.load()` antes de runApp().
class VeloraLanguageStore {
  VeloraLanguageStore._();

  static const _storageKey = 'velora.interface_language';
  static final ValueNotifier<VeloraLanguage> current =
      ValueNotifier<VeloraLanguage>(VeloraLanguage.ptBR);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    current.value = VeloraLanguage.values.firstWhere(
      (language) => language.code == saved,
      orElse: () => VeloraLanguage.ptBR,
    );
  }

  static Future<void> select(VeloraLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_storageKey, language.code);
    if (!saved) throw StateError('Não foi possível salvar o idioma.');
    current.value = language;
  }
}

/// Traduções iniciais. Mais chaves serão incluídas quando cada tela for ligada.
class VeloraText {
  static const Map<String, Map<VeloraLanguage, String>> _strings = {
    'language': {
      VeloraLanguage.ptBR: 'Idioma',
      VeloraLanguage.en: 'Language',
      VeloraLanguage.es: 'Idioma',
    },
    'choose_language': {
      VeloraLanguage.ptBR: 'Escolha o seu idioma',
      VeloraLanguage.en: 'Choose your language',
      VeloraLanguage.es: 'Elige tu idioma',
    },
    'continue': {
      VeloraLanguage.ptBR: 'Continuar',
      VeloraLanguage.en: 'Continue',
      VeloraLanguage.es: 'Continuar',
    },
    'login': {
      VeloraLanguage.ptBR: 'Entrar',
      VeloraLanguage.en: 'Sign in',
      VeloraLanguage.es: 'Iniciar sesión',
    },
    'email': {
      VeloraLanguage.ptBR: 'E-mail',
      VeloraLanguage.en: 'Email',
      VeloraLanguage.es: 'Correo electrónico',
    },
    'password': {
      VeloraLanguage.ptBR: 'Senha',
      VeloraLanguage.en: 'Password',
      VeloraLanguage.es: 'Contraseña',
    },
    'invalid_credentials': {
      VeloraLanguage.ptBR: 'E-mail ou senha inválidos.',
      VeloraLanguage.en: 'Invalid email or password.',
      VeloraLanguage.es: 'Correo electrónico o contraseña incorrectos.',
    },
    'delete_account': {
      VeloraLanguage.ptBR: 'Excluir minha conta',
      VeloraLanguage.en: 'Delete my account',
      VeloraLanguage.es: 'Eliminar mi cuenta',
    },
    'cancel': {
      VeloraLanguage.ptBR: 'Cancelar',
      VeloraLanguage.en: 'Cancel',
      VeloraLanguage.es: 'Cancelar',
    },
  };

  static String get(String key, [VeloraLanguage? language]) {
    final selected = language ?? VeloraLanguageStore.current.value;
    final translations = _strings[key];
    return translations?[selected] ?? translations?[VeloraLanguage.ptBR] ?? key;
  }
}
DART

echo 'Velora: estrutura de idiomas criada (pt_BR, en, es).'
echo 'Próxima etapa: integrar ao main.dart e às telas. Nenhuma tela foi alterada.'
