import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_palette.dart';

class AppLoader extends ConsumerWidget {
  const AppLoader({super.key, this.message = 'Cargando información...'});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 74,
            height: 74,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 28, offset: const Offset(0, 14))],
            ),
            child: CircularProgressIndicator(strokeWidth: 3, color: palette.onPrimary),
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
