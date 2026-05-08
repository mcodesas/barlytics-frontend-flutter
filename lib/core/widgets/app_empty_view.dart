import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({super.key, this.message = 'No hay registros para mostrar'});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.border),
              boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 14))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(gradient: AppColors.bluePurpleGradient, shape: BoxShape.circle),
                  child: const Icon(Icons.inbox_rounded, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text('Sin información', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
}
