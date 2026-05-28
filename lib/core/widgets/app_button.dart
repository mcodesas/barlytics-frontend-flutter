import 'package:flutter/material.dart';

/// Botón principal reutilizable con gradiente sincronizado con la paleta activa.
class AppButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = loading || onPressed == null;
    final gradient = LinearGradient(
      colors: [scheme.primary, scheme.secondary, scheme.tertiary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: scheme.onPrimary),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: scheme.onPrimary),
                const SizedBox(width: 9),
              ],
              Text(label, style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w900)),
            ],
          );

    return Opacity(
      opacity: disabled ? 0.62 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: disabled ? null : gradient,
          color: disabled ? scheme.onSurface.withOpacity(0.28) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(disabled ? 0.08 : 0.18)),
          boxShadow: disabled
              ? const []
              : [
                  BoxShadow(
                    color: scheme.secondary.withOpacity(0.30),
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
            foregroundColor: scheme.onPrimary,
            minimumSize: const Size.fromHeight(54),
          ),
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
      ),
    );
  }
}
