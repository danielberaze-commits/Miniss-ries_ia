#!/usr/bin/env bash
set -euo pipefail
# Velora: etapa 2 - mensagem inicial remota, sem mudar o layout V5.
# Executar DEPOIS de velora_home_acessibilidade_fix.sh e da etapa 1.
python3 - <<'PY'
from pathlib import Path
p = Path('lib/screens/home_screen.dart')
service = Path('lib/services/velora_remote_config.dart')
if not p.is_file() or not service.is_file():
    raise SystemExit('ERRO: HomeScreen ou servico remoto ausente. Confira a ordem do workflow.')
s = p.read_text(encoding='utf-8')
import_line = "import '../services/velora_remote_config.dart';"
if import_line not in s:
    anchor = "import 'package:flutter/material.dart';"
    if s.count(anchor) != 1:
        raise SystemExit('ERRO: import Flutter nao localizado; nada alterado.')
    s = s.replace(anchor, anchor + '\n' + import_line, 1)
state_anchor = 'class _HomeScreenState extends State<HomeScreen> {'
future_line = '  late final Future<bool> _veloraRemoteHomeFuture = VeloraRemoteConfig.refresh();'
if future_line not in s:
    if s.count(state_anchor) != 1:
        raise SystemExit('ERRO: classe HomeScreen nao localizada; nada alterado.')
    s = s.replace(state_anchor, state_anchor + '\n' + future_line, 1)
old = """child: Text(
                  'O próximo capítulo começa aqui',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),"""
new = """child: FutureBuilder<bool>(
                  future: _veloraRemoteHomeFuture,
                  builder: (context, snapshot) {
                    final remoteMessage = VeloraRemoteConfig.home['welcome_message'];
                    final message = remoteMessage is String && remoteMessage.trim().isNotEmpty
                        ? remoteMessage.trim()
                        : 'O próximo capítulo começa aqui';
                    return Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    );
                  },
                ),"""
if s.count(old) != 1:
    raise SystemExit(f'ERRO: titulo centralizado V5 nao encontrado exatamente uma vez (ocorrencias={s.count(old)}). Nada alterado.')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
print('OK: mensagem inicial remota integrada, mantendo rolagem e centralizacao V5.')
PY
