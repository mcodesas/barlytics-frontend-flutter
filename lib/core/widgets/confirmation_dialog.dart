import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
        scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: AppColors.warningSoft, shape: BoxShape.circle),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
      content: Text(message, style: const TextStyle(color: AppColors.textSecondary, height: 1.35)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton.icon(onPressed: () => Navigator.pop(context, true), icon: const Icon(Icons.check_rounded), label: const Text('Confirmar')),
      ],
    ),
  );
  return result ?? false;
}
