import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../crud/crud_field.dart';
import '../crud/crud_module_config.dart';
import '../crud/crud_notifier.dart';
import '../crud/crud_remote_datasource.dart';
import '../crud/crud_repository.dart';
import '../crud/crud_state.dart';
import '../providers/core_providers.dart';
import '../utils/validators.dart';
import 'app_button.dart';
import 'app_loader.dart';
import 'app_text_field.dart';

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
  bool _loadingInitial = false;

  @override
  void initState() {
    super.initState();
    for (final field in widget.config.formFields) {
      _controllers[field.name] = TextEditingController();
    }
    if (widget.id != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loadingInitial = true);
    final repository = CrudRepository<T>(CrudRemoteDataSource<T>(ref.read(apiClientProvider), widget.config));
    final item = await repository.findById(widget.id!);
    final json = widget.config.toJson(item);
    for (final field in widget.config.formFields) {
      _controllers[field.name]?.text = json[field.name]?.toString() ?? '';
    }
    setState(() => _loadingInitial = false);
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
    final provider = StateNotifierProvider.autoDispose<CrudNotifier<T>, CrudState<T>>((ref) {
      final repository = CrudRepository<T>(CrudRemoteDataSource<T>(ref.watch(apiClientProvider), widget.config));
      return CrudNotifier<T>(repository);
    });
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    if (_loadingInitial) return const Scaffold(body: AppLoader());

    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? 'Crear ${widget.config.title}' : 'Editar ${widget.config.title}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in widget.config.formFields) ...[
                  AppTextField(
                    controller: _controllers[field.name]!,
                    label: field.label,
                    keyboardType: _keyboardType(field.type),
                    validator: field.required ? Validators.required : null,
                    readOnly: field.readOnly,
                  ),
                  const SizedBox(height: 16),
                ],
                if (state.failure != null) Text(state.failure!.message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Guardar',
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
              ],
            ),
          ),
        ),
      ),
    );
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
