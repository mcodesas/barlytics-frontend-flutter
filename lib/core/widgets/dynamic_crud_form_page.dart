import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/module_visuals.dart';
import '../crud/crud_field.dart';
import '../crud/crud_module_config.dart';
import '../crud/crud_notifier.dart';
import '../crud/crud_remote_datasource.dart';
import '../crud/crud_repository.dart';
import '../crud/crud_state.dart';
import '../providers/core_providers.dart';
import '../utils/responsive_utils.dart';
import '../utils/validators.dart';
import 'app_button.dart';
import 'app_loader.dart';
import 'app_text_field.dart';
import 'lookup_dropdown.dart';

final Map<String, List<CrudLookupOption>> _lookupCache = <String, List<CrudLookupOption>>{};

/// Formulario genérico para crear y editar registros CRUD con diseño responsive.
class DynamicCrudFormPage<T> extends ConsumerStatefulWidget {
  const DynamicCrudFormPage({super.key, required this.config, this.id});

  final CrudModuleConfig<T> config;
  final String? id;

  @override
  ConsumerState<DynamicCrudFormPage<T>> createState() => _DynamicCrudFormPageState<T>();
}

class _DynamicCrudFormPageState<T> extends ConsumerState<DynamicCrudFormPage<T>> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _lookupOptions = <String, List<CrudLookupOption>>{};
  final _lookupErrors = <String, String>{};
  final _loadingLookupFields = <String>{};

  late final AutoDisposeStateNotifierProvider<CrudNotifier<T>, CrudState<T>> _provider;
  bool _loadingInitial = false;

  @override
  void initState() {
    super.initState();
    _provider = StateNotifierProvider.autoDispose<CrudNotifier<T>, CrudState<T>>((ref) {
      final repository = CrudRepository<T>(
        CrudRemoteDataSource<T>(ref.watch(apiClientProvider), widget.config),
      );
      return CrudNotifier<T>(repository);
    });

    for (final field in widget.config.formFields) {
      _controllers[field.name] = TextEditingController();
    }

    _loadLookupOptions();
    if (widget.id != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loadingInitial = true);
    try {
      final repository = CrudRepository<T>(CrudRemoteDataSource<T>(ref.read(apiClientProvider), widget.config));
      final item = await repository.findById(widget.id!);
      final json = widget.config.toJson(item);
      for (final field in widget.config.formFields) {
        _controllers[field.name]?.text = json[field.name]?.toString() ?? '';
      }
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadLookupOptions() async {
    final lookupFields = widget.config.formFields.where((field) => field.lookup != null).toList();
    if (lookupFields.isEmpty) return;

    final apiClient = ref.read(apiClientProvider);

    for (final field in lookupFields) {
      final lookup = field.lookup!;
      final cacheKey = '${lookup.endpoint}|${lookup.idField}|${lookup.displayFields.join(',')}';

      if (_lookupCache.containsKey(cacheKey)) {
        _lookupOptions[field.name] = _lookupCache[cacheKey]!;
        continue;
      }

      _loadingLookupFields.add(field.name);
      if (mounted) setState(() {});

      try {
        final response = await apiClient.get<List<CrudLookupOption>>(
          lookup.endpoint,
          (json) {
            final items = json is List ? json : const [];
            return items.whereType<Map>().map((item) {
              final raw = Map<String, dynamic>.from(item);
              final id = raw[lookup.idField];
              if (id == null) return null;
              final labelParts = lookup.displayFields
                  .map((displayField) => raw[displayField]?.toString().trim() ?? '')
                  .where((value) => value.isNotEmpty)
                  .toList();
              final fallback = id.toString();
              final label = labelParts.isEmpty ? fallback : '${labelParts.join(' - ')} (#$fallback)';
              return CrudLookupOption(id: id, label: label, raw: raw);
            }).whereType<CrudLookupOption>().toList();
          },
        );
        final options = response.data ?? <CrudLookupOption>[];
        _lookupCache[cacheKey] = options;
        _lookupOptions[field.name] = options;
        _lookupErrors.remove(field.name);
      } catch (error) {
        _lookupErrors[field.name] = 'No fue posible cargar la ayuda de ${field.label}';
      } finally {
        _loadingLookupFields.remove(field.name);
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final notifier = ref.read(_provider.notifier);
    final visual = ModuleVisuals.byKey(widget.config.key);
    final isEditing = widget.id != null;

    if (_loadingInitial) return const Scaffold(body: AppLoader());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 190,
            title: Text(isEditing ? 'Editar ${widget.config.title}' : 'Crear ${widget.config.title}'),
            leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/${widget.config.key}')),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [visual.color.withOpacity(0.18), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 58, 20, 16),
                    child: Row(
                      children: [
                        Container(width: 58, height: 58, decoration: BoxDecoration(color: visual.color, borderRadius: BorderRadius.circular(22)), child: Icon(visual.icon, color: Colors.white, size: 30)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(isEditing ? 'Editar registro' : 'Nuevo registro', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text('Completa la información de ${widget.config.title.toLowerCase()}.', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final twoColumns = !ResponsiveUtils.isMobile(context) && constraints.maxWidth > 720;
                            final fieldWidth = twoColumns ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  spacing: 20,
                                  runSpacing: 16,
                                  children: [
                                    for (final field in widget.config.formFields)
                                      SizedBox(width: fieldWidth, child: _buildField(field)),
                                  ],
                                ),
                                if (state.failure != null) ...[
                                  const SizedBox(height: 18),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(18)),
                                    child: Text(state.failure!.message, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
                                  ),
                                ],
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: state.loading ? null : () => context.go('/${widget.config.key}'),
                                        icon: const Icon(Icons.close_rounded),
                                        label: const Text('Cancelar'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: AppButton(
                                        label: 'Guardar',
                                        icon: Icons.save_rounded,
                                        loading: state.loading,
                                        onPressed: () async {
                                          if (!_formKey.currentState!.validate()) return;
                                          final body = <String, dynamic>{};
                                          for (final field in widget.config.formFields) {
                                            final text = _controllers[field.name]!.text.trim();
                                            body[field.name] = _parse(text, field.type);
                                          }
                                          final ok = await notifier.save(id: widget.id, body: body);
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Registro guardado correctamente' : 'No fue posible guardar')));
                                          if (ok) context.go('/${widget.config.key}');
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(CrudField field) {
    if (field.lookup != null) {
      return LookupDropdown(
        controller: _controllers[field.name]!,
        field: field,
        options: _lookupOptions[field.name] ?? const <CrudLookupOption>[],
        loading: _loadingLookupFields.contains(field.name),
        errorMessage: _lookupErrors[field.name],
      );
    }

    return AppTextField(
      controller: _controllers[field.name]!,
      label: field.label,
      prefixIcon: _iconForField(field),
      keyboardType: _keyboardType(field.type),
      validator: field.required ? Validators.required : null,
      readOnly: field.readOnly,
    );
  }

  IconData _iconForField(CrudField field) {
    final name = field.name.toLowerCase();
    if (name.contains('email') || name.contains('correo')) return Icons.email_outlined;
    if (name.contains('telefono')) return Icons.phone_outlined;
    if (name.contains('direccion')) return Icons.location_on_outlined;
    if (name.contains('fecha')) return Icons.event_outlined;
    if (field.type == CrudFieldType.number || field.type == CrudFieldType.decimal) return Icons.numbers_rounded;
    return Icons.edit_outlined;
  }

  TextInputType _keyboardType(CrudFieldType type) => switch (type) {
        CrudFieldType.number => TextInputType.number,
        CrudFieldType.decimal => const TextInputType.numberWithOptions(decimal: true),
        _ => TextInputType.text,
      };

  Object? _parse(String value, CrudFieldType type) {
    if (value.isEmpty) return null;
    return switch (type) {
      CrudFieldType.number => int.tryParse(value),
      CrudFieldType.decimal => double.tryParse(value.replaceAll(',', '.')),
      CrudFieldType.boolean => value == 'true' || value == '1',
      _ => value,
    };
  }
}
