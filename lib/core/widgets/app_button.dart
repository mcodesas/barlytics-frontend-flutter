import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_palette.dart';

/// Botón principal reutilizable con gradiente tecnológico.
class AppButton extends ConsumerWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disabled = loading || onPressed == null;
    final palette = ref.watch(selectedAppPaletteProvider);
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 9),
              ],
              Text(label, style: const TextStyle(color: Colors.white)),
            ],
          );

    return Opacity(
      opacity: disabled ? 0.62 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: disabled ? AppColors.textMuted : palette.actionColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: disabled
              ? const []
              : [
                  BoxShadow(
                    color: palette.actionColor.withOpacity(0.30),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
          ),
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
      ),
    );
  }
}
