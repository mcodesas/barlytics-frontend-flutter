import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../crud/crud_module_config.dart';
import '../crud/crud_remote_datasource.dart';
import '../crud/crud_repository.dart';
import '../providers/core_providers.dart';
import 'app_error_view.dart';
import 'app_loader.dart';

class DynamicCrudDetailPage<T> extends ConsumerWidget {
  const DynamicCrudDetailPage({super.key, required this.config, required this.id});
  final CrudModuleConfig<T> config;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = CrudRepository<T>(CrudRemoteDataSource<T>(ref.watch(apiClientProvider), config));
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle ${config.title}'),
        actions: [IconButton(onPressed: () => context.go('/${config.key}/$id/editar'), icon: const Icon(Icons.edit))],
      ),
      body: FutureBuilder<T>(
        future: repository.findById(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const AppLoader();
          if (snapshot.hasError) return AppErrorView(message: snapshot.error.toString());
          final item = snapshot.data;
          if (item == null) return const AppErrorView(message: 'Registro no encontrado');
          final json = config.toJson(item);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final field in config.fields)
                Card(
                  child: ListTile(
                    title: Text(field.label),
                    subtitle: Text('${json[field.name] ?? '-'}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
