import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Muestra la semilla de generación "de forma sutil" y ofrece copiarla al
/// portapapeles (front#37). Reutilizado por el HUD de la partida y por la
/// pantalla post-partida, para que el jugador pueda reproducir un tablero.
class SeedChip extends StatelessWidget {
  final int seed;

  /// Estilo compacto para la AppBar (HUD) vs. destacado en la post-partida.
  final bool compact;

  const SeedChip({super.key, required this.seed, this.compact = false});

  Future<void> _copy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: '$seed'));
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.seedCopied),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;
    final textStyle = (compact
            ? Theme.of(context).textTheme.bodySmall
            : Theme.of(context).textTheme.bodyMedium)
        ?.copyWith(color: muted, letterSpacing: 0.5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            l10n.seedLabel(seed),
            style: textStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: Icon(Icons.copy_rounded,
              size: compact ? 16 : 20, color: muted),
          tooltip: l10n.copySeed,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: compact ? 32 : 40,
            minHeight: compact ? 32 : 40,
          ),
          onPressed: () => _copy(context),
        ),
      ],
    );
  }
}
