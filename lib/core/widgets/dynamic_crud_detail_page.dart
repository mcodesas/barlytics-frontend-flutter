import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/module_visuals.dart';
import '../crud/crud_field.dart';
import '../crud/crud_field_ordering.dart';
import '../crud/crud_lookup_resolver.dart';
import '../crud/crud_module_config.dart';
import '../crud/crud_remote_datasource.dart';
import '../crud/crud_repository.dart';
import '../providers/core_providers.dart';
import 'app_error_view.dart';
import 'app_loader.dart';
import 'tech_background.dart';

/// Página genérica de detalle con diseño tipo ficha móvil/tablet.
class DynamicCrudDetailPage<T> extends ConsumerStatefulWidget {
  const DynamicCrudDetailPage({super.key, required this.config, required this.id});

  final CrudModuleConfig<T> config;
  final String id;

  @override
  ConsumerState<DynamicCrudDetailPage<T>> createState() => _DynamicCrudDetailPageState<T>();
}

class _DynamicCrudDetailPageState<T> extends ConsumerState<DynamicCrudDetailPage<T>> {
  late Future<T> _future;
  Map<String, Map<String, String>> _lookupLabels = const <String, Map<String, String>>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadLookupLabels();
  }

  Future<T> _load() {
    final repository = CrudRepository<T>(CrudRemoteDataSource<T>(ref.read(apiClientProvider), widget.config));
    return repository.findById(widget.id);
  }

  Future<void> _loadLookupLabels() async {
    final resolver = CrudLookupResolver(ref.read(apiClientProvider));
    final labels = await resolver.resolveLabels(widget.config.fields);
    if (!mounted) return;
    setState(() => _lookupLabels = labels);
  }

  void _reload() {
    setState(() => _future = _load());
    _loadLookupLabels();
  }

  @override
  Widget build(BuildContext context) {
    final visual = ModuleVisuals.byKey(widget.config.key);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<T>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const AppLoader();
          if (snapshot.hasError) return AppErrorView(message: snapshot.error.toString(), onRetry: _reload);
          final item = snapshot.data;
          if (item == null) return const AppErrorView(message: 'No fue posible cargar el registro');
          final json = widget.config.toJson(item);
          final firstField = crudPrimaryField(widget.config);
          final title = _displayValue(firstField, json[firstField.name]);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                foregroundColor: Colors.white,
                expandedHeight: 210,
                title: Text(widget.config.title),
                leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/${widget.config.key}')),
                actions: [
                  IconButton(onPressed: () => context.go('/${widget.config.key}/${widget.id}/editar'), icon: const Icon(Icons.edit_rounded), tooltip: 'Editar'),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: TechBackground(
                    padding: const EdgeInsets.fromLTRB(20, 58, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [visual.color, AppColors.tertiary]),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [BoxShadow(color: visual.color.withOpacity(0.30), blurRadius: 24, offset: const Offset(0, 12))],
                          ),
                          child: Icon(visual.icon, color: Colors.white, size: 35),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(title == '-' ? widget.config.title : title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                for (final field in crudVisibleFields(widget.config))
                                  _DetailItem(
                                    label: field.label,
                                    value: _displayValue(field, json[field.name]),
                                    color: field.lookup != null ? visual.color : AppColors.textSecondary,
                                    icon: _iconForField(field),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _displayValue(CrudField field, Object? rawValue) {
    return crudDisplayValue(field, rawValue, _lookupLabels);
  }

  IconData _iconForField(CrudField field) {
    final name = field.name.toLowerCase();
    if (field.lookup != null) return Icons.link_rounded;
    if (name.contains('email') || name.contains('correo')) return Icons.email_outlined;
    if (name.contains('telefono')) return Icons.phone_outlined;
    if (name.contains('fecha')) return Icons.event_outlined;
    if (name.contains('estado')) return Icons.flag_outlined;
    return Icons.info_outline_rounded;
  }
}


class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value, required this.color, required this.icon});

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.sizeOf(context).width < 700;
    return SizedBox(
      width: isSmall ? double.infinity : 300,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white, color.withOpacity(0.07)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(value, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
