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
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(color: AppColors.infoSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.inbox_rounded, size: 36, color: AppColors.info),
                ),
                const SizedBox(height: 16),
                Text('Sin información', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
}
