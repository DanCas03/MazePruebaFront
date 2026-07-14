import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/state/configurator_controller.dart';
import '../../application/state/generated_game_controller.dart';
import '../../domain/arrows/value_objects/difficulty.dart';
import '../../domain/arrows/value_objects/generator_config.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// Configurador del flujo de tableros generados (front#37). El jugador elige su
/// INTENCIÓN — tamaño (4–10), dificultad, contrarreloj y semilla opcional — y
/// [GeneratorConfig] deriva los parámetros internos del generador. "Jugar" se
/// deshabilita reactivamente (Riverpod) mientras el formulario sea inválido
/// (única fuente de invalidez práctica: una semilla no numérica).
class ConfiguratorScreen extends ConsumerWidget {
  const ConfiguratorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final form = ref.watch(configuratorControllerProvider);
    final controller = ref.read(configuratorControllerProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;
    final onFilled = isDark ? AppColors.background : AppColors.lightSurface;

    void play() {
      // Monta el tablero ANTES de navegar para que la pantalla de juego lo
      // encuentre listo. Cortafuegos: startNew solo genera en memoria.
      ref.read(generatedGameControllerProvider.notifier).startNew(form.toConfig());
      Navigator.pushReplacementNamed(context, AppRouter.generatedGame);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: surface,
        title: Text(l10n.configuratorTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            _DimensionSelector(
              label: l10n.configColumns,
              value: form.cols,
              onChanged: controller.setCols,
            ),
            const SizedBox(height: 8),
            _DimensionSelector(
              label: l10n.configRows,
              value: form.rows,
              onChanged: controller.setRows,
            ),
            const SizedBox(height: 24),
            Text(l10n.configDifficulty,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<Difficulty>(
              segments: [
                ButtonSegment(
                    value: Difficulty.easy, label: Text(l10n.difficultyEasy)),
                ButtonSegment(
                    value: Difficulty.medium,
                    label: Text(l10n.difficultyMedium)),
                ButtonSegment(
                    value: Difficulty.hard, label: Text(l10n.difficultyHard)),
              ],
              selected: {form.difficulty},
              onSelectionChanged: (s) => controller.setDifficulty(s.first),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.configTimed),
              secondary: const Icon(Icons.timer_outlined),
              value: form.timed,
              activeThumbColor: primary,
              onChanged: controller.setTimed,
            ),
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              inputFormatters: [
                // Solo dígitos (y un signo opcional al inicio): guía al jugador
                // hacia una semilla válida; la validación real vive en el estado.
                FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
              ],
              decoration: InputDecoration(
                labelText: l10n.configSeedOptional,
                prefixIcon: const Icon(Icons.tag),
                border: const OutlineInputBorder(),
                errorText: form.isSeedValid ? null : l10n.configSeedInvalid,
              ),
              onChanged: controller.setSeedText,
            ),
            const SizedBox(height: 32),
            FilledButton(
              // Deshabilitado (onPressed null) mientras el formulario es
              // inválido: el criterio de aceptación de #37.
              onPressed: form.isValid ? play : null,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: onFilled,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                l10n.configPlay,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selector numérico del rango jugable [GeneratorConfig.minDimension]–
/// [GeneratorConfig.maxDimension] con botones -/+ que se desactivan en los
/// extremos. Fuente única del rango: no puede pedir un tamaño fuera de él.
class _DimensionSelector extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _DimensionSelector({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canDecrement = value > GeneratorConfig.minDimension;
    final canIncrement = value < GeneratorConfig.maxDimension;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton.outlined(
          icon: const Icon(Icons.remove),
          onPressed: canDecrement ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton.outlined(
          icon: const Icon(Icons.add),
          onPressed: canIncrement ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
