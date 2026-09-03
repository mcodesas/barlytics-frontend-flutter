import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../parametros/data/models/parametros_response_model.dart';
import '../../../sucursales/data/models/sucursales_response_model.dart';
import '../providers/business_setup_provider.dart';

class BusinessSetupOperationalParametersPage extends ConsumerStatefulWidget {
  const BusinessSetupOperationalParametersPage({super.key});

  @override
  ConsumerState<BusinessSetupOperationalParametersPage> createState() =>
      _BusinessSetupOperationalParametersPageState();
}

class _BusinessSetupOperationalParametersPageState
    extends ConsumerState<BusinessSetupOperationalParametersPage> {
  static const _code = 'PEDIDO_WHATSAPP_DESTINO';

  final _generalController = TextEditingController();
  final Map<int, TextEditingController> _branchControllers = {};
  final Map<int?, ParametrosResponseModel> _existing = {};
  List<SucursalesResponseModel> _branches = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generalController.dispose();
    for (final controller in _branchControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait<Object>([
        api.get<List<ParametrosResponseModel>>(
          ApiPaths.parametros,
          (json) => (json as List? ?? const <Object?>[])
              .whereType<Map>()
              .map((item) => ParametrosResponseModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false),
        ),
        api.get<List<SucursalesResponseModel>>(
          ApiPaths.sucursales,
          (json) => (json as List? ?? const <Object?>[])
              .whereType<Map>()
              .map((item) => SucursalesResponseModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false),
        ),
      ]);

      final params = (results[0] as dynamic).data as List<ParametrosResponseModel>? ?? const [];
      final branches = (results[1] as dynamic).data as List<SucursalesResponseModel>? ?? const [];

      _existing.clear();
      for (final parameter in params) {
        if ((parameter.paraCodigo ?? '').trim().toUpperCase() != _code) continue;
        if (parameter.paraEstado == 0) continue;
        _existing[parameter.sucuId] = parameter;
      }

      _generalController.text = _displayValue(_existing[null]);
      _branches = branches.where((branch) => branch.sucuEstado != 0).toList(growable: false);

      final activeIds = _branches.map((branch) => branch.sucuId).whereType<int>().toSet();
      final staleIds = _branchControllers.keys.where((id) => !activeIds.contains(id)).toList();
      for (final id in staleIds) {
        _branchControllers.remove(id)?.dispose();
      }
      for (final branch in _branches) {
        final id = branch.sucuId;
        if (id == null) continue;
        final controller = _branchControllers.putIfAbsent(id, TextEditingController.new);
        controller.text = _displayValue(_existing[id]);
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(error);
      });
    }
  }

  String _displayValue(ParametrosResponseModel? parameter) {
    if (parameter == null) return '';
    final value = parameter.paraValor?.trim() ?? '';
    if (value.isNotEmpty) return value;
    return parameter.paraValorDefecto?.trim() ?? '';
  }

  Future<void> _save() async {
    final general = _normalizeWhatsapp(_generalController.text);
    if (!_isValidWhatsapp(general)) {
      setState(() {
        _error = 'Ingresa un número general válido entre 10 y 15 dígitos, incluyendo indicativo de país.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _upsertParameter(
        existing: _existing[null],
        branchId: null,
        value: general,
        name: 'WhatsApp general para pedidos',
        description:
            'Número predeterminado que recibirá los pedidos de reposición del negocio.',
      );

      for (final branch in _branches) {
        final branchId = branch.sucuId;
        if (branchId == null) continue;
        final raw = _branchControllers[branchId]?.text ?? '';
        final value = _normalizeWhatsapp(raw);
        final existing = _existing[branchId];

        if (value.isEmpty) {
          if (existing?.paraId != null && _displayValue(existing).isNotEmpty) {
            await ref.read(apiClientProvider).delete<Object?>(
                  '${ApiPaths.parametros}/${existing!.paraId}',
                  (json) => json,
                );
          }
          continue;
        }

        if (!_isValidWhatsapp(value)) {
          throw StateError(
            'El número de ${branch.label()} debe tener entre 10 y 15 dígitos.',
          );
        }

        await _upsertParameter(
          existing: existing,
          branchId: branchId,
          value: value,
          name: 'WhatsApp pedidos - ${branch.label()}',
          description:
              'Número opcional para pedidos de esta sucursal. Tiene prioridad sobre el número general.',
        );
      }

      ref.invalidate(businessSetupStatusProvider);
      await ref.read(authControllerProvider.notifier).refreshBusinessSetup();
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración de pedidos guardada correctamente.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _upsertParameter({
    required ParametrosResponseModel? existing,
    required int? branchId,
    required String value,
    required String name,
    required String description,
  }) async {
    final api = ref.read(apiClientProvider);
    final body = <String, dynamic>{
      'sucuId': branchId,
      'paraCodigo': _code,
      'paraNombre': name,
      'paraDescripcion': description,
      'paraTipoDato': 'TEXTO',
      'paraValor': value,
      'paraValorDefecto': '',
      'paraGrupo': 'PEDIDOS',
      'paraEditable': 1,
      'paraEstado': 1,
    };

    ParametrosResponseModel parser(Object? json) =>
        ParametrosResponseModel.fromJson(Map<String, dynamic>.from(json as Map));

    if (existing?.paraId != null) {
      await api.put<ParametrosResponseModel>(
        '${ApiPaths.parametros}/${existing!.paraId}',
        body,
        parser,
      );
    } else {
      await api.post<ParametrosResponseModel>(
        ApiPaths.parametros,
        body,
        parser,
      );
    }
  }

  String _normalizeWhatsapp(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10 && digits.startsWith('3')) {
      digits = '57$digits';
    }
    return digits;
  }

  bool _isValidWhatsapp(String value) => value.length >= 10 && value.length <= 15;

  String _cleanError(Object error) {
    final text = error.toString().trim();
    return text.replaceFirst(
      RegExp(r'^(Exception|StateError|ApiException):\s*'),
      '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: palette.secondary));
    }

    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 720 ? 16 : 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pedidos',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Define a qué WhatsApp se enviarán los pedidos de reposición. El número consecutivo del pedido lo genera BarLytics automáticamente y no necesita configuración.',
                  style: TextStyle(
                    color: palette.textSecondary,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                _ParameterCard(
                  title: 'WhatsApp general para pedidos',
                  description:
                      'Este número se usará como destino predeterminado para todas las sucursales.',
                  requiredField: true,
                  child: TextField(
                    controller: _generalController,
                    maxLength: 15,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(15)],
                    decoration: const InputDecoration(
                      labelText: 'Número con indicativo de país',
                      hintText: 'Ej. 573001234567',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ),
                if (_branches.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ParameterCard(
                    title: 'Números por sucursal',
                    description:
                        'Opcional. Úsalo solo si alguna sede envía sus pedidos a un número diferente del general.',
                    requiredField: false,
                    child: Column(
                      children: [
                        for (var i = 0; i < _branches.length; i++) ...[
                          TextField(
                            controller: _branchControllers[_branches[i].sucuId],
                            maxLength: 15,
                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(15),
                            ],
                            decoration: InputDecoration(
                              labelText: _branches[i].label(),
                              hintText: 'Usar el número general',
                              prefixIcon: const Icon(Icons.store_outlined),
                            ),
                          ),
                          if (i != _branches.length - 1) const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.danger.withOpacity(.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.danger.withOpacity(.22)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline_rounded, color: palette.danger, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: palette.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Guardando...' : 'Guardar parámetros'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ParameterCard extends ConsumerWidget {
  const _ParameterCard({
    required this.title,
    required this.description,
    required this.requiredField,
    required this.child,
  });

  final String title;
  final String description;
  final bool requiredField;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder.withOpacity(.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (requiredField)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.secondary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Esencial',
                    style: TextStyle(
                      color: palette.secondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(color: palette.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
