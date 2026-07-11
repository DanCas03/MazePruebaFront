import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/state/audio_settings_controller.dart';
import '../../../application/state/locale_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Pantalla de Ajustes (front#19): controles INDEPENDIENTES de Musica (BGM) y
/// Efectos (SFX) sobre la fachada de audio, y selector de idioma ES/EN. Todo
/// persiste y el idioma se aplica EN VIVO (el MaterialApp observa el
/// [localeControllerProvider]). Solo presentacion: delega la logica en los
/// controllers reactivos y sus casos de uso.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final audio = ref.watch(audioSettingsControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    // Codigo efectivo: el elegido o, si se sigue al SO, el locale resuelto.
    final currentCode =
        locale?.languageCode ?? Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsAudioSection),
          SwitchListTile(
            secondary: const Icon(Icons.music_note),
            title: Text(l10n.settingsMusic),
            // El switch muestra "sonando" (ON) = NO muteado.
            value: !audio.musicMuted,
            onChanged: (_) =>
                ref.read(audioSettingsControllerProvider.notifier).toggleMusic(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.graphic_eq),
            title: Text(l10n.settingsSfx),
            value: !audio.sfxMuted,
            onChanged: (_) =>
                ref.read(audioSettingsControllerProvider.notifier).toggleSfx(),
          ),
          const Divider(height: 32),
          _SectionHeader(l10n.settingsLanguageSection),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment<String>(
                  value: 'es',
                  label: Text(l10n.languageSpanish),
                ),
                ButtonSegment<String>(
                  value: 'en',
                  label: Text(l10n.languageEnglish),
                ),
              ],
              selected: {currentCode == 'en' ? 'en' : 'es'},
              onSelectionChanged: (selection) => ref
                  .read(localeControllerProvider.notifier)
                  .setLanguage(Locale(selection.first)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado de seccion de la lista de ajustes.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
      ),
    );
  }
}
