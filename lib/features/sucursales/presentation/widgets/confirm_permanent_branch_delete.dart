import 'package:flutter/material.dart';

/// Requires the exact branch name before allowing irreversible deletion.
/// Closing the dialog or pressing Cancel never calls the API.
Future<String?> confirmPermanentBranchDeletion(
  BuildContext context, {
  required String branchName,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ConfirmPermanentBranchDeletionDialog(
      branchName: branchName,
    ),
  );
}

class _ConfirmPermanentBranchDeletionDialog extends StatefulWidget {
  const _ConfirmPermanentBranchDeletionDialog({required this.branchName});

  final String branchName;

  @override
  State<_ConfirmPermanentBranchDeletionDialog> createState() =>
      _ConfirmPermanentBranchDeletionDialogState();
}

class _ConfirmPermanentBranchDeletionDialogState
    extends State<_ConfirmPermanentBranchDeletionDialog> {
  final TextEditingController _confirmation = TextEditingController();

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExactMatch = _confirmation.text.trim() == widget.branchName.trim();
    final theme = Theme.of(context);
    return AlertDialog(
        scrollable: true,
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          const Expanded(child: Text('Eliminar sucursal definitivamente')),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se eliminará la sucursal «${widget.branchName}» y la información vinculada exclusivamente a ella.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Esto incluye productos, existencias, movimientos, pedidos, '
                'mesas, ventas, pagos, cierres de caja, gastos y demás registros '
                'propios de la sucursal. Las cuentas de usuario se conservarán, '
                'pero se desvincularán de esta sede.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Esta acción no se puede deshacer. Exporta los reportes y '
                'respalda la información que debas conservar antes de continuar.',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Text('Para confirmar, escribe exactamente: ${widget.branchName}'),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmation,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Nombre de la sucursal',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: isExactMatch
              ? () => Navigator.of(context).pop(_confirmation.text.trim())
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.delete_forever_rounded),
          label: const Text('Eliminar definitivamente'),
        ),
      ],
    );
  }
}
