#!/usr/bin/env bash
set -euo pipefail
# Execute depois da etapa 2. Diagnostico temporario, sem modificar layout.
python3 - <<'PY'
from pathlib import Path
p=Path('lib/services/velora_remote_config.dart')
if not p.is_file():
    raise SystemExit('ERRO: servico remoto ausente.')
s=p.read_text(encoding='utf-8')
if "import 'package:flutter/foundation.dart';" not in s:
    anchor="import 'package:supabase_flutter/supabase_flutter.dart';"
    if s.count(anchor)!=1: raise SystemExit('ERRO: import esperado ausente.')
    s=s.replace(anchor, "import 'package:flutter/foundation.dart';\n"+anchor,1)
old="""      _theme = {..._defaultTheme, ...?next['theme']};
      return true;
    } catch (_) {
      // Mantem a ultima configuracao valida, ou os valores padrao.
      return false;
"""
new="""      _theme = {..._defaultTheme, ...?next['theme']};
      debugPrint('VELORA_REMOTE_CONFIG: consulta OK; chaves=${next.keys.toList()}; mensagem=${_home['welcome_message']}');
      return true;
    } catch (error) {
      debugPrint('VELORA_REMOTE_CONFIG: consulta FALHOU: $error');
      // Mantem a ultima configuracao valida, ou os valores padrao.
      return false;
"""
if s.count(old)!=1:
    raise SystemExit('ERRO: bloco refresh esperado nao encontrado; nada alterado.')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
print('OK: logs de diagnostico adicionados ao servico remoto.')
PY
