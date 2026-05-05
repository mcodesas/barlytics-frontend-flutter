import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.message = 'Cargando información...'});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.14), blurRadius: 28, offset: const Offset(0, 14))],
              ),
              child: const CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
