import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../crud/crud_field.dart';

/// Campo reutilizable para seleccionar registros relacionados desde una ayuda.
class LookupDropdown extends StatelessWidget {
  const LookupDropdown({
    super.key,
    required this.controller,
    required this.field,
    required this.options,
    this.loading = false,
    this.errorMessage,
    this.enabled = true,
    this.helperText,
    this.onSelected,
  });

  final TextEditingController controller;
  final CrudField field;
  final List<CrudLookupOption> options;
  final bool loading;
  final String? errorMessage;
  final bool enabled;
  final String? helperText;
  final ValueChanged<CrudLookupOption>? onSelected;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: ValueKey('${field.name}-${controller.text}-${options.length}'),
      initialValue: controller.text,
      validator: field.required
          ? (value) {
              if (value == null || value.trim().isEmpty) return 'Campo obligatorio';
              return null;
            }
          : null,
      builder: (state) {
        final selectedId = (state.value ?? controller.text).trim();
        final selected = options.where((option) => option.id?.toString() == selectedId).firstOrNull;
        final displayValue = selected?.label ?? (selectedId.isEmpty ? '' : 'Opción seleccionada');

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: field.readOnly || loading || !enabled ? null : () => _openLookupDialog(context, state),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: field.label,
              prefixIcon: const Icon(Icons.manage_search_rounded),
              errorText: state.errorText,
              helperText: errorMessage ?? helperText ?? (loading ? 'Cargando opciones...' : enabled ? 'Toca para buscar y seleccionar' : 'Selecciona primero el dato anterior'),
              suffixIcon: loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : Icon(enabled ? Icons.keyboard_arrow_down_rounded : Icons.lock_outline_rounded),
            ),
            child: Text(
              displayValue.isEmpty ? 'Seleccione una opción' : displayValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: displayValue.isEmpty ? const TextStyle(color: AppColors.textSecondary) : const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openLookupDialog(BuildContext context, FormFieldState<String> fieldState) async {
    final searchController = TextEditingController();
    var filtered = List<CrudLookupOption>.from(options);

    final selected = await showDialog<CrudLookupOption>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            void filter(String value) {
              final query = value.trim().toLowerCase();
              setState(() {
                filtered = query.isEmpty
                    ? List<CrudLookupOption>.from(options)
                    : options.where((option) => option.label.toLowerCase().contains(query)).toList();
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              contentPadding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
              title: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: AppColors.infoSoft, shape: BoxShape.circle),
                    child: const Icon(Icons.manage_search_rounded, color: AppColors.info),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Seleccionar ${field.label}', style: const TextStyle(fontWeight: FontWeight.w900))),
                ],
              ),
              content: SizedBox(
                width: 560,
                height: 460,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nombre, código o descripción',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: filter,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No hay opciones disponibles', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final option = filtered[index];
                                return Material(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(18),
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    leading: const CircleAvatar(backgroundColor: AppColors.infoSoft, child: Icon(Icons.check_circle_outline_rounded, color: AppColors.info)),
                                    title: Text(option.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                                    onTap: () => Navigator.of(dialogContext).pop(option),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
              ],
            );
          },
        );
      },
    );

    searchController.dispose();
    if (selected == null) return;

    final selectedId = selected.id?.toString() ?? '';
    controller.text = selectedId;
    fieldState.didChange(selectedId);
    onSelected?.call(selected);
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
