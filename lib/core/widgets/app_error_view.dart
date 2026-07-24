import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_palette.dart';

class AppErrorView extends ConsumerWidget {
  const AppErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.danger.withOpacity(0.22)),
            boxShadow: [BoxShadow(color: AppColors.danger.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 14))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(26)),
                child: const Icon(Icons.error_outline_rounded, size: 38, color: AppColors.danger),
              ),
              const SizedBox(height: 16),
              Text('Algo salió mal', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
