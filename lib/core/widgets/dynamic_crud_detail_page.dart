import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_palette.dart';
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

/// Página genérica de detalle con el mismo lenguaje visual del panel administrativo.
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

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _loadLookupLabels();
  }

  @override
  Widget build(BuildContext context) {
    final visual = ModuleVisuals.byKey(widget.config.key);
    final palette = ref.watch(selectedAppPaletteProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          FutureBuilder<T>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const AppLoader();
              if (snapshot.hasError) return AppErrorView(message: snapshot.error.toString(), onRetry: _reload);
              final item = snapshot.data;
              if (item == null) return AppErrorView(message: 'No fue posible cargar el registro', onRetry: _reload);

              final json = widget.config.toJson(item);
              final firstField = crudPrimaryField(widget.config);
              final title = _displayValue(firstField, json[firstField.name]);
              final fields = crudVisibleFields(widget.config);

              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: _DetailToolbar(
                          title: title == '-' ? widget.config.title : title,
                          moduleTitle: widget.config.title,
                          icon: visual.icon,
                          palette: palette,
                          onBack: () => context.go('/${widget.config.key}'),
                          onEdit: () => context.go('/${widget.config.key}/${widget.id}/editar'),
                          onRefresh: _reload,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: palette.cardBorder),
                            boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 24, offset: const Offset(0, 12))],
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final itemWidth = constraints.maxWidth < 720
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 28) / 2;
                              return Wrap(
                                spacing: 14,
                                runSpacing: 14,
                                children: [
                                  for (final field in fields)
                                    SizedBox(
                                      width: field.type == CrudFieldType.image ? constraints.maxWidth : itemWidth,
                                      child: _DetailItem(
                                        field: field,
                                        value: _displayValue(field, json[field.name]),
                                        palette: palette,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _displayValue(CrudField field, Object? rawValue) => crudDisplayValue(field, rawValue, _lookupLabels);
}

class _DetailToolbar extends StatelessWidget {
  const _DetailToolbar({
    required this.title,
    required this.moduleTitle,
    required this.icon,
    required this.palette,
    required this.onBack,
    required this.onEdit,
    required this.onRefresh,
  });

  final String title;
  final String moduleTitle;
  final IconData icon;
  final AppPalette palette;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.secondary.withOpacity(0.16)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final heading = Row(
            children: [
              IconButton.filledTonal(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded), tooltip: 'Volver'),
              const SizedBox(width: 10),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: palette.onPrimary, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detalle de $moduleTitle', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
                    const SizedBox(height: 3),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 19)),
                  ],
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Actualizar')),
              FilledButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_rounded), label: const Text('Editar')),
            ],
          );

          if (compact) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [heading, const SizedBox(height: 14), Align(alignment: Alignment.centerRight, child: actions)]);
          }
          return Row(children: [Expanded(child: heading), const SizedBox(width: 16), actions]);
        },
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.field, required this.value, required this.palette});

  final CrudField field;
  final String value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    if (field.type == CrudFieldType.image) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.background.withOpacity(palette.darkBackground ? 0.40 : 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label, style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _DetailImage(value: value, palette: palette),
          ],
        ),
      );
    }

    final accent = field.lookup != null ? palette.secondary : palette.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.70),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.13)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(_iconForField(field), color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(value, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForField(CrudField field) {
    final name = field.name.toLowerCase();
    if (field.lookup != null) return Icons.link_rounded;
    if (name.contains('email') || name.contains('correo')) return Icons.email_outlined;
    if (name.contains('telefono')) return Icons.phone_outlined;
    if (name.contains('fecha')) return Icons.event_outlined;
    if (name.contains('estado')) return Icons.toggle_on_rounded;
    if (name.contains('direccion')) return Icons.location_on_outlined;
    if (field.type == CrudFieldType.number || field.type == CrudFieldType.decimal) return Icons.numbers_rounded;
    return Icons.info_outline_rounded;
  }
}

class _DetailImage extends StatelessWidget {
  const _DetailImage({required this.value, required this.palette});

  final String value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final normalized = value.trim();
    final placeholder = Container(
      width: double.infinity,
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: palette.surface.withOpacity(0.72), borderRadius: BorderRadius.circular(18)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, color: palette.textSecondary, size: 34),
          const SizedBox(height: 8),
          Text('Sin imagen configurada', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
    if (normalized.isEmpty || normalized == '-') return placeholder;

    Widget image;
    if (normalized.startsWith('data:image')) {
      final comma = normalized.indexOf(',');
      if (comma < 0) return placeholder;
      try {
        image = Image.memory(base64Decode(normalized.substring(comma + 1)), fit: BoxFit.contain);
      } catch (_) {
        return placeholder;
      }
    } else {
      image = Image.network(normalized, fit: BoxFit.contain, errorBuilder: (_, __, ___) => placeholder);
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220, maxHeight: 360),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: image,
    );
  }
}
