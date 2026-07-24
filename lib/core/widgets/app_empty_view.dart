import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_palette.dart';

class AppEmptyView extends ConsumerWidget {
  const AppEmptyView({super.key, this.message = 'No hay registros para mostrar'});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: palette.cardBorder),
            boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 24, offset: const Offset(0, 14))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [palette.primary, palette.secondary]), shape: BoxShape.circle),
                child: Icon(Icons.inbox_rounded, size: 36, color: palette.onPrimary),
              ),
              const SizedBox(height: 16),
              Text('Sin información', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
