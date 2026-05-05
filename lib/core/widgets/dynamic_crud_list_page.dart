import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../crud/crud_module_config.dart';
import '../crud/crud_notifier.dart';
import '../crud/crud_remote_datasource.dart';
import '../crud/crud_repository.dart';
import '../crud/crud_state.dart';
import '../providers/core_providers.dart';
import '../utils/responsive_utils.dart';
import 'app_empty_view.dart';
import 'app_error_view.dart';
import 'app_loader.dart';
import 'confirmation_dialog.dart';

class DynamicCrudListPage<T> extends ConsumerWidget {
  const DynamicCrudListPage({super.key, required this.config});
  final CrudModuleConfig<T> config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = StateNotifierProvider.autoDispose<CrudNotifier<T>, CrudState<T>>((ref) {
      final repository = CrudRepository<T>(CrudRemoteDataSource<T>(ref.watch(apiClientProvider), config));
      return CrudNotifier<T>(repository)..load();
    });
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    Widget content;
    if (state.loading && state.items.isEmpty) {
      content = const AppLoader();
    } else if (state.failure != null) {
      content = AppErrorView(message: state.failure!.message, onRetry: notifier.load);
    } else if (state.items.isEmpty) {
      content = const AppEmptyView();
    } else {
      content = ResponsiveUtils.isDesktop(context)
          ? _DesktopTable(config: config, items: state.items, onDelete: (id) async => _delete(context, notifier, id))
          : _MobileCards(config: config, items: state.items, onDelete: (id) async => _delete(context, notifier, id));
    }

    return Scaffold(
      appBar: AppBar(title: Text(config.title), actions: [IconButton(onPressed: notifier.load, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/${config.key}/nuevo'),
        icon: const Icon(Icons.add),
        label: const Text('Crear'),
      ),
      body: content,
    );
  }

  Future<void> _delete(BuildContext context, CrudNotifier<T> notifier, Object id) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Confirmar eliminación',
      message: '¿Deseas eliminar o inactivar este registro?',
    );
    if (!confirmed) return;
    final ok = await notifier.remove(id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Registro procesado correctamente' : 'No fue posible procesar el registro')));
    }
  }
}

Object? _valueOf<T>(CrudModuleConfig<T> config, T item, String field) {
  final json = config.toJson(item);
  return json[field];
}

class _MobileCards<T> extends StatelessWidget {
  const _MobileCards({required this.config, required this.items, required this.onDelete});
  final CrudModuleConfig<T> config;
  final List<T> items;
  final Future<void> Function(Object id) onDelete;

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final id = _valueOf(config, item, config.idField) ?? index;
          final title = config.fields.take(3).map((f) => _valueOf(config, item, f.name)).where((e) => e != null).join(' · ');
          return Card(
            child: ListTile(
              title: Text(title.isEmpty ? '${config.title} $id' : title),
              subtitle: Text('${config.idField}: $id'),
              onTap: () => context.go('/${config.key}/$id'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') context.go('/${config.key}/$id/editar');
                  if (value == 'delete') onDelete(id);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar/Inactivar')),
                ],
              ),
            ),
          );
        },
      );
}

class _DesktopTable<T> extends StatelessWidget {
  const _DesktopTable({required this.config, required this.items, required this.onDelete});
  final CrudModuleConfig<T> config;
  final List<T> items;
  final Future<void> Function(Object id) onDelete;

  @override
  Widget build(BuildContext context) {
    final columns = config.fields.take(6).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columns: [for (final f in columns) DataColumn(label: Text(f.label)), const DataColumn(label: Text('Acciones'))],
          rows: [
            for (final item in items)
              DataRow(
                cells: [
                  for (final f in columns) DataCell(Text('${_valueOf(config, item, f.name) ?? '-'}')),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(onPressed: () => context.go('/${config.key}/${_valueOf(config, item, config.idField)}'), icon: const Icon(Icons.visibility)),
                    IconButton(onPressed: () => context.go('/${config.key}/${_valueOf(config, item, config.idField)}/editar'), icon: const Icon(Icons.edit)),
                    IconButton(onPressed: () => onDelete(_valueOf(config, item, config.idField) ?? ''), icon: const Icon(Icons.delete_outline)),
                  ])),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
