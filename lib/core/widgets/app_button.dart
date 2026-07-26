import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_control_metrics.dart';
import '../../app/theme/app_palette.dart';

/// Botón principal reutilizable.
///
/// El tamaño predeterminado es compacto para evitar acciones exageradamente
/// altas en formularios administrativos. Usa [compact] para barras y paneles
/// secundarios; las pantallas móviles pueden seguir estirándolo con un padre.
class AppButton extends ConsumerWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disabled = loading || onPressed == null;
    final palette = ref.watch(selectedAppPaletteProvider);
    final height = compact ? AppControlMetrics.compactButtonHeight : AppControlMetrics.buttonHeight;
    final radius = compact ? 12.0 : 14.0;
    final child = loading
        ? SizedBox(
            width: compact ? 17 : 18,
            height: compact ? 17 : 18,
            child: const CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 17 : 18, color: Colors.white),
                SizedBox(width: compact ? 6 : 7),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 12.5 : 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          );

    return Opacity(
      opacity: disabled ? 0.62 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: disabled ? AppColors.textMuted : palette.actionColor,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: disabled
              ? const []
              : [
                  BoxShadow(
                    color: palette.actionColor.withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            minimumSize: Size(0, height),
            maximumSize: Size(double.infinity, height),
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 15),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          ),
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
      ),
    );
  }
}
