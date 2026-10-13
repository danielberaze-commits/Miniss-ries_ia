#!/usr/bin/env bash
set -euo pipefail

# Velora - etapa 1: cliente seguro para leitura de configuracoes remotas.
# Execute apos todos os scripts de telas/traducoes, antes de flutter pub get.
# Esta etapa nao modifica as telas nem ativa manutencao automaticamente.

if [[ ! -f lib/main.dart || ! -f pubspec.yaml ]]; then
  echo 'ERRO: execute na raiz do projeto Flutter gerado.' >&2
  exit 1
fi
mkdir -p lib/services
cat > lib/services/velora_remote_config.dart <<'DART'
import 'package:supabase_flutter/supabase_flutter.dart';

/// Le apenas configuracoes publicas. Falhas de rede nao impedem o app de abrir.
class VeloraRemoteConfig {
  VeloraRemoteConfig._();

  static const Map<String, dynamic> _defaultHome = {
    'banner_url': '',
    'show_featured': true,
    'welcome_message': 'O próximo capítulo começa aqui',
  };
  static const Map<String, dynamic> _defaultMaintenance = {
    'enabled': false,
    'message': 'Estamos preparando novidades para você.',
  };
  static const Map<String, dynamic> _defaultTheme = {
    'background': '#08070E',
    'surface': '#17121F',
    'gold': '#EBC58C',
    'purple': '#8B2BEE',
  };

  static Map<String, dynamic> _home = Map.of(_defaultHome);
  static Map<String, dynamic> _maintenance = Map.of(_defaultMaintenance);
  static Map<String, dynamic> _theme = Map.of(_defaultTheme);

  static Map<String, dynamic> get home => Map.unmodifiable(_home);
  static Map<String, dynamic> get maintenance => Map.unmodifiable(_maintenance);
  static Map<String, dynamic> get theme => Map.unmodifiable(_theme);

  static Future<bool> refresh() async {
    try {
      final rows = await Supabase.instance.client
          .from('app_config')
          .select('key,value')
          .eq('is_public', true);
      final next = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final key = row['key'];
        final value = row['value'];
        if (key is String && value is Map) {
          next[key] = Map<String, dynamic>.from(value);
        }
      }
      _home = {..._defaultHome, ...?next['home']};
      _maintenance = {..._defaultMaintenance, ...?next['maintenance']};
      _theme = {..._defaultTheme, ...?next['theme']};
      return true;
    } catch (_) {
      // Mantem a ultima configuracao valida, ou os valores padrao.
      return false;
    }
  }
}
DART

echo 'OK: servico de configuracoes remotas criado. Nenhuma tela foi alterada.'
