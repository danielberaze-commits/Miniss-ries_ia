#!/usr/bin/env bash
set -euo pipefail

# Executar apos velora_language_integration.sh.
# Substitui apenas o widget seletor gerado pelo script anterior.
python3 - <<'PY'
from pathlib import Path
p = Path('lib/velora_language_selector.dart')
lang = Path('lib/l10n/velora_language.dart')
if not p.exists() or not lang.exists():
    raise SystemExit('ERRO: execute apos velora_language_upgrade.sh e velora_language_integration.sh.')
original = p.read_text(encoding='utf-8')
if 'class VeloraLanguageSelector' not in original:
    raise SystemExit('ERRO: seletor atual nao reconhecido; arquivo preservado.')
p.write_text(r'''import 'package:flutter/material.dart';
import 'l10n/velora_language.dart';

class VeloraLanguageSelector extends StatelessWidget {
  const VeloraLanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.language, color: Color(0xFFEBC58C)),
      title: Text(VeloraText.get('language')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const VeloraLanguageScreen(),
        ),
      ),
    );
  }
}

class VeloraLanguageScreen extends StatefulWidget {
  const VeloraLanguageScreen({super.key});

  @override
  State<VeloraLanguageScreen> createState() => _VeloraLanguageScreenState();
}

class _VeloraLanguageScreenState extends State<VeloraLanguageScreen> {
  late VeloraLanguage _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = VeloraLanguageStore.current.value;
  }

  String _headline() => switch (VeloraLanguageStore.current.value) {
    VeloraLanguage.ptBR => 'Escolha seu idioma',
    VeloraLanguage.en => 'Choose your language',
    VeloraLanguage.es => 'Elige tu idioma',
  };

  String _subtitle() => switch (VeloraLanguageStore.current.value) {
    VeloraLanguage.ptBR => 'Personalize sua experiência no Velora',
    VeloraLanguage.en => 'Personalize your Velora experience',
    VeloraLanguage.es => 'Personaliza tu experiencia en Velora',
  };

  String _error() => switch (VeloraLanguageStore.current.value) {
    VeloraLanguage.ptBR => 'Não foi possível salvar o idioma.',
    VeloraLanguage.en => 'Could not save the language.',
    VeloraLanguage.es => 'No se pudo guardar el idioma.',
  };

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await VeloraLanguageStore.select(_selected);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _option(VeloraLanguage language, String flag, String name, String region) {
    final chosen = _selected == language;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1C1628),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selected = language),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: chosen ? const Color(0xFFAB69FF) : const Color(0xFF342A44),
                width: chosen ? 2 : 1,
              ),
            ),
            child: Row(children: [
              Text(flag, style: const TextStyle(fontSize: 29)),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(region, style: const TextStyle(
                    color: Color(0xFFBDB5C9), fontSize: 12)),
                ],
              )),
              Icon(chosen ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: chosen ? const Color(0xFFAB69FF) : const Color(0xFF81768F)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0812),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0812),
        foregroundColor: const Color(0xFFEBC58C),
        centerTitle: true,
        title: const Text('VELORA', style: TextStyle(
          color: Color(0xFFEBC58C), letterSpacing: 3,
          fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          const SizedBox(height: 34),
          const Icon(Icons.language, color: Color(0xFFAB69FF), size: 48),
          const SizedBox(height: 20),
          Text(_headline(), textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white,
              fontSize: 27, fontWeight: FontWeight.bold)),
          const SizedBox(height: 9),
          Text(_subtitle(), textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFBDB5C9), fontSize: 14)),
          const SizedBox(height: 34),
          _option(VeloraLanguage.ptBR, '🇧🇷', 'Português', 'Brasil'),
          _option(VeloraLanguage.en, '🇺🇸', 'English', 'United States'),
          _option(VeloraLanguage.es, '🇪🇸', 'Español', 'España / Latinoamérica'),
          const Spacer(),
          SizedBox(width: double.infinity, height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _confirm,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B2BEE),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                ? const SizedBox(height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(
    switch (_selected) {
      VeloraLanguage.ptBR => 'Continuar',
      VeloraLanguage.en => 'Continue',
      VeloraLanguage.es => 'Continuar',
    },
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  ),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      )),
    );
  }
}
''', encoding='utf-8')
print('OK: tela premium de idiomas criada e conectada ao Perfil.')
PY
