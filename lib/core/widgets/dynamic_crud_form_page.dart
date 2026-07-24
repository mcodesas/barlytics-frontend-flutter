import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/module_visuals.dart';
import '../crud/crud_field.dart';
import '../crud/crud_field_ordering.dart';
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
import 'tech_background.dart';

final Map<String, List<CrudLookupOption>> _lookupCache = <String, List<CrudLookupOption>>{};

/// Formulario genérico para crear y editar registros CRUD con diseño responsive.
class DynamicCrudFormPage<T> extends ConsumerStatefulWidget {
  const DynamicCrudFormPage({
    super.key,
    required this.config,
    this.id,
    this.onSaved,
    this.wizardSteps,
    this.currentWizardStep = 0,
    this.initialValues = const <String, dynamic>{},
  });

  final CrudModuleConfig<T> config;
  final String? id;
  final void Function(BuildContext context, T saved)? onSaved;

  /// Lista opcional de pasos para flujos asistidos, por ejemplo:
  /// Empresa -> Sucursales -> Finalizar.
  /// Se muestra dentro de la tarjeta principal para que el usuario entienda
  /// que el primer formulario no es el final del proceso.
  final List<String>? wizardSteps;
  final int currentWizardStep;
  final Map<String, dynamic> initialValues;

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
      final initialValue = widget.initialValues[field.name];
      _controllers[field.name] = TextEditingController(
        text: initialValue == null ? '' : initialValue.toString(),
      );
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
                  .where((displayField) => !displayField.toLowerCase().endsWith('id'))
                  .map((displayField) => raw[displayField]?.toString().trim() ?? '')
                  .where((value) => value.isNotEmpty)
                  .toList();
              final label = labelParts.isEmpty ? 'Opción disponible' : labelParts.join(' - ');
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
    final palette = ref.watch(selectedAppPaletteProvider);
    final isEditing = widget.id != null;

    if (_loadingInitial) return const Scaffold(backgroundColor: Colors.transparent, body: AppLoader());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          CustomScrollView(
            slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: _FormContextHeader(
                    title: isEditing ? 'Editar registro' : 'Nuevo registro',
                    subtitle: 'Completa la información de ${widget.config.title.toLowerCase()}.',
                    icon: visual.icon,
                    palette: palette,
                    onBack: () => context.go('/${widget.config.key}'),
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
                    color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.98),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: palette.cardBorder)),
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
                                if (widget.wizardSteps != null && widget.wizardSteps!.isNotEmpty) ...[
                                  _WizardStepsTabs(
                                    steps: widget.wizardSteps!,
                                    currentStep: widget.currentWizardStep,
                                    palette: palette,
                                  ),
                                  const SizedBox(height: 22),
                                  Text(
                                    widget.currentWizardStep == 0
                                        ? 'Paso 1: registra primero los datos principales. Al guardar continuarás con la creación de sucursales.'
                                        : 'Continúa completando los pasos del proceso.',
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                ],
                                Wrap(
                                  spacing: 20,
                                  runSpacing: 16,
                                  children: [
                                    for (final field in crudVisibleFields(widget.config, fields: widget.config.formFields))
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
                                LayoutBuilder(
                                  builder: (context, actionConstraints) {
                                    final cancelButton = OutlinedButton.icon(
                                      onPressed: state.loading ? null : () => context.go('/${widget.config.key}'),
                                      icon: const Icon(Icons.close_rounded),
                                      label: const Text('Cancelar'),
                                    );
                                    final saveButton = AppButton(
                                      label: widget.wizardSteps != null && widget.id == null ? 'Guardar y continuar' : 'Guardar',
                                      icon: Icons.save_rounded,
                                      loading: state.loading,
                                      onPressed: () async {
                                        if (!_formKey.currentState!.validate()) return;
                                        final body = <String, dynamic>{};
                                        for (final field in widget.config.formFields) {
                                          if (crudIsTechnicalIdField(widget.config, field)) continue;
                                          final text = _controllers[field.name]!.text.trim();
                                          body[field.name] = field.type == CrudFieldType.image ? text : _parse(text, field.type);
                                        }
                                        final saved = await notifier.saveAndReturn(id: widget.id, body: body);
                                        if (!context.mounted) return;
                                        final ok = saved != null;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Registro guardado correctamente' : 'No fue posible guardar')));
                                        if (ok) {
                                          if (widget.onSaved != null) {
                                            widget.onSaved!(context, saved);
                                          } else {
                                            context.go('/${widget.config.key}');
                                          }
                                        }
                                      },
                                    );
                                    if (actionConstraints.maxWidth < 520) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [cancelButton, const SizedBox(height: 10), saveButton],
                                      );
                                    }
                                    return Row(
                                      children: [
                                        Expanded(child: cancelButton),
                                        const SizedBox(width: 12),
                                        Expanded(child: saveButton),
                                      ],
                                    );
                                  },
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
        ],
      ),
    );
  }

  Widget _buildField(CrudField field) {
    final palette = ref.watch(selectedAppPaletteProvider);
    if (field.type == CrudFieldType.boolean) {
      return _BooleanField(
        controller: _controllers[field.name]!,
        label: field.label,
        readOnly: field.readOnly,
        palette: palette,
      );
    }

    if (field.type == CrudFieldType.image) {
      return _ImageField(
        controller: _controllers[field.name]!,
        label: field.label,
        required: field.required,
        readOnly: field.readOnly,
        palette: palette,
      );
    }

    if (field.options != null && field.options!.isNotEmpty) {
      return _FixedOptionsDropdown(
        controller: _controllers[field.name]!,
        field: field,
        palette: palette,
      );
    }

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
    if (field.type == CrudFieldType.image || name.contains('foto') || name.contains('logo')) return Icons.image_rounded;
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
      CrudFieldType.boolean => (value == 'true' || value == '1') ? 1 : 0,
      _ => value,
    };
  }
}



class _FormContextHeader extends StatelessWidget {
  const _FormContextHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.palette,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final AppPalette palette;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.secondary.withOpacity(0.15)),
      ),
      child: Row(
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
                Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedOptionsDropdown extends StatelessWidget {
  const _FixedOptionsDropdown({
    required this.controller,
    required this.field,
    required this.palette,
  });

  final TextEditingController controller;
  final CrudField field;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final options = field.options ?? const <String, String>{};
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final selected = options.containsKey(value.text) ? value.text : null;
        return DropdownButtonFormField<String>(
          value: selected,
          decoration: InputDecoration(
            labelText: field.label,
            prefixIcon: const Icon(Icons.compare_arrows_rounded),
            filled: true,
            fillColor: palette.background.withOpacity(palette.darkBackground ? 0.42 : 0.72),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
          items: options.entries
              .map((item) => DropdownMenuItem<String>(
                    value: item.key,
                    child: Text(item.value),
                  ))
              .toList(growable: false),
          onChanged: field.readOnly ? null : (newValue) => controller.text = newValue ?? '',
          validator: field.required
              ? (newValue) => newValue == null || newValue.isEmpty ? 'Este campo es obligatorio' : null
              : null,
        );
      },
    );
  }
}

class _BooleanField extends StatelessWidget {
  const _BooleanField({
    required this.controller,
    required this.label,
    required this.readOnly,
    required this.palette,
  });

  final TextEditingController controller;
  final String label;
  final bool readOnly;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final normalized = value.text.trim().toLowerCase();
        final active = normalized == '1' || normalized == 'true';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.success.withOpacity(0.08) : palette.background.withOpacity(palette.darkBackground ? 0.42 : 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? AppColors.success.withOpacity(0.28) : palette.cardBorder,
            ),
          ),
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: active,
            onChanged: readOnly
                ? null
                : (newValue) {
                    controller.text = newValue ? '1' : '0';
                  },
            title: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(
              active ? 'Disponible para cobros de esta sucursal' : 'No se mostrará al momento de pagar en esta sucursal',
              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
            ),
            secondary: Icon(
              active ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded,
              color: active ? AppColors.success : palette.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

class _ImageField extends StatefulWidget {
  const _ImageField({
    required this.controller,
    required this.label,
    required this.required,
    required this.readOnly,
    required this.palette,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final bool readOnly;
  final AppPalette palette;

  @override
  State<_ImageField> createState() => _ImageFieldState();
}

class _ImageFieldState extends State<_ImageField> {
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) return;
    final ext = (file?.extension ?? 'png').toLowerCase();
    final mime = ext == 'jpg' || ext == 'jpeg'
        ? 'image/jpeg'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/png';
    widget.controller.text = 'data:$mime;base64,${base64Encode(bytes)}';
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text.trim();
    return FormField<String>(
      validator: widget.required && value.isEmpty ? (_) => 'Este campo es obligatorio' : null,
      builder: (state) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.palette.background.withOpacity(widget.palette.darkBackground ? 0.42 : 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: state.hasError ? AppColors.danger : widget.palette.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image_rounded, color: widget.palette.secondary),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w900))),
                if (!widget.readOnly)
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Cargar'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (value.isEmpty)
              Container(
                width: double.infinity,
                height: 104,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: widget.palette.surface.withOpacity(0.72), borderRadius: BorderRadius.circular(16)),
                child: Text('Sin imagen cargada', style: TextStyle(color: widget.palette.textSecondary, fontWeight: FontWeight.w700)),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _ImagePreview(value: value, palette: widget.palette),
              ),
            if (value.isNotEmpty && !widget.readOnly) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    widget.controller.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Quitar foto'),
                ),
              ),
            ],
            if (state.hasError) ...[
              const SizedBox(height: 6),
              Text(state.errorText ?? '', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.value, required this.palette});

  final String value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final imageValue = value.trim();
    if (imageValue.isEmpty) {
      return Container(
        width: double.infinity,
        height: 120,
        alignment: Alignment.center,
        color: palette.surface.withOpacity(0.72),
        child: Text('Sin imagen cargada', style: TextStyle(color: palette.textSecondary)),
      );
    }
    if (imageValue.startsWith('data:image')) {
      final commaIndex = imageValue.indexOf(',');
      if (commaIndex > -1) {
        try {
          final bytes = base64Decode(imageValue.substring(commaIndex + 1));
          return Image.memory(bytes, width: double.infinity, height: 150, fit: BoxFit.cover);
        } catch (_) {}
      }
    }
    return Image.network(
      imageValue,
      width: double.infinity,
      height: 150,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: double.infinity,
        height: 120,
        alignment: Alignment.center,
        color: palette.surface.withOpacity(0.72),
        child: Text('No fue posible previsualizar la imagen', style: TextStyle(color: palette.textSecondary)),
      ),
    );
  }
}

class _WizardStepsTabs extends StatelessWidget {
  const _WizardStepsTabs({required this.steps, required this.currentStep, required this.palette});

  final List<String> steps;
  final int currentStep;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: palette.glassGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final children = List.generate(steps.length, (index) {
            final selected = index == currentStep;
            final completed = index < currentStep;
            final icon = completed ? Icons.check_circle_rounded : Icons.radio_button_checked_rounded;
            final content = AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: selected ? LinearGradient(colors: [palette.primary, palette.secondary]) : null,
                color: selected ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center,
                mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? palette.onPrimary
                        : completed
                            ? AppColors.success
                            : palette.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Paso ${index + 1}: ${steps[index]}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? palette.onPrimary : palette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
            return compact ? content : Expanded(child: content);
          });

          if (compact) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
          }
          return Row(children: children);
        },
      ),
    );
  }
}
