import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/state/audio_settings_controller.dart';
import '../../../application/state/locale_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Valor centinela del segmento "Sistema" del selector de idioma: representa la
/// ausencia de preferencia (seguir el locale del SO) sin usar un `null` en el
/// `Set` del [SegmentedButton].
const String _systemSegment = 'system';

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
    // Segmento seleccionado: refleja la ELECCION explicita del usuario.
    // `null` (seguir al SO) => 'system'; en otro caso, el codigo del locale.
    final selectedSegment = locale == null ? _systemSegment : locale.languageCode;

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
                ButtonSegment<String>(
                  value: _systemSegment,
                  label: Text(l10n.languageSystem),
                ),
              ],
              selected: {selectedSegment},
              onSelectionChanged: (selection) {
                final choice = selection.first;
                // 'system' vuelve a seguir el locale del SO (setLanguage(null)),
                // haciendo alcanzable desde la UI el estado sin preferencia.
                ref.read(localeControllerProvider.notifier).setLanguage(
                      choice == _systemSegment ? null : Locale(choice),
                    );
              },
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
