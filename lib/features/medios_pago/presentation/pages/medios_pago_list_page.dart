import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../sucursales/data/models/sucursales_response_model.dart';
import '../../data/models/medios_pago_response_model.dart';

/// Panel administrativo para activar medios de pago y cargar el QR propio de
/// cada sucursal. El catálogo de medios permanece global; la configuración es
/// independiente por sede.
class MediosPagoListPage extends ConsumerStatefulWidget {
  const MediosPagoListPage({super.key});

  @override
  ConsumerState<MediosPagoListPage> createState() => _MediosPagoListPageState();
}

class _MediosPagoListPageState extends ConsumerState<MediosPagoListPage> {
  List<SucursalesResponseModel> _sucursales = const [];
  List<MediosPagoResponseModel> _medios = const [];
  final Set<int> _guardando = <int>{};

  int? _sucursalId;
  bool _cargandoSucursales = true;
  bool _cargandoMedios = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_cargarSucursales);
  }

  Future<void> _cargarSucursales() async {
    if (mounted) {
      setState(() {
        _cargandoSucursales = true;
        _error = null;
      });
    }

    try {
      final response = await ref.read(apiClientProvider).get<List<SucursalesResponseModel>>(
        '/api/v1/mediospago/sucursales',
        (json) => _parseSucursales(json),
      );
      final sucursales = response.data ?? const <SucursalesResponseModel>[];
      final firstActive = sucursales.where((item) => item.sucuEstado == 1 && item.sucuId != null).firstOrNull;
      final selected = _sucursalId != null && sucursales.any((item) => item.sucuId == _sucursalId)
          ? _sucursalId
          : (firstActive?.sucuId ?? sucursales.where((item) => item.sucuId != null).firstOrNull?.sucuId);

      if (!mounted) return;
      setState(() {
        _sucursales = sucursales;
        _sucursalId = selected;
        _cargandoSucursales = false;
      });
      if (selected != null) {
        await _cargarMedios(selected);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cargandoSucursales = false;
        _error = _mensajeError(error);
      });
    }
  }

  Future<void> _cargarMedios(int sucursalId) async {
    setState(() {
      _cargandoMedios = true;
      _error = null;
      _medios = const [];
    });

    try {
      final response = await ref.read(apiClientProvider).get<List<MediosPagoResponseModel>>(
        '/api/v1/mediospago/sucursal/$sucursalId',
        (json) => _parseMedios(json),
      );
      if (!mounted || _sucursalId != sucursalId) return;
      setState(() {
        _medios = response.data ?? const <MediosPagoResponseModel>[];
        _cargandoMedios = false;
      });
    } catch (error) {
      if (!mounted || _sucursalId != sucursalId) return;
      setState(() {
        _cargandoMedios = false;
        _error = _mensajeError(error);
      });
    }
  }

  Future<void> _seleccionarSucursal(int? value) async {
    if (value == null || value == _sucursalId || _guardando.isNotEmpty) return;
    setState(() => _sucursalId = value);
    await _cargarMedios(value);
  }

  Future<void> _actualizarMedio(
    MediosPagoResponseModel medio, {
    int? estado,
    String? qr,
    bool enviarQr = false,
  }) async {
    final sucursalId = _sucursalId;
    final medioId = medio.mepaId;
    if (sucursalId == null || medioId == null || _guardando.contains(medioId)) return;

    setState(() => _guardando.add(medioId));
    try {
      final body = <String, dynamic>{
        'mepaNombre': medio.mepaNombre,
        'mepaDescripcion': medio.mepaDescripcion,
        'mepaEstado': estado ?? medio.mepaEstado ?? 0,
        if (enviarQr) 'mepaQr': qr ?? '',
      };
      final response = await ref.read(apiClientProvider).put<MediosPagoResponseModel>(
        '/api/v1/mediospago/sucursal/$sucursalId/$medioId',
        body,
        (json) => MediosPagoResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
      );
      final updated = response.data;
      if (!mounted || updated == null || _sucursalId != sucursalId) return;
      setState(() {
        _medios = _medios
            .map((item) => item.mepaId == updated.mepaId ? updated : item)
            .toList(growable: false);
      });
    } catch (error) {
      if (mounted) _mostrarMensaje(_mensajeError(error), error: true);
    } finally {
      if (mounted) setState(() => _guardando.remove(medioId));
    }
  }

  Future<void> _cargarQr(MediosPagoResponseModel medio) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _mostrarMensaje('No fue posible leer la imagen seleccionada.', error: true);
      return;
    }
    if (bytes.length > 4 * 1024 * 1024) {
      _mostrarMensaje('El QR no puede superar 4 MB.', error: true);
      return;
    }

    final extension = (file.extension ?? 'png').toLowerCase();
    final mime = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/png',
    };
    await _actualizarMedio(
      medio,
      qr: 'data:$mime;base64,${base64Encode(bytes)}',
      enviarQr: true,
    );
  }

  Future<void> _quitarQr(MediosPagoResponseModel medio) async {
    await _actualizarMedio(medio, qr: '', enviarQr: true);
  }

  void _mostrarMensaje(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final sucursal = _sucursales.where((item) => item.sucuId == _sucursalId).firstOrNull;
    final activos = _medios.where((item) => item.mepaEstado == 1).length;
    final conQr = _medios.where((item) => (item.mepaQr ?? '').trim().isNotEmpty).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: _cargarSucursales,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1240),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ControlHeader(
                                palette: palette,
                                sucursales: _sucursales,
                                selectedSucursalId: _sucursalId,
                                loading: _cargandoSucursales,
                                disabled: _guardando.isNotEmpty,
                                onChanged: _seleccionarSucursal,
                              ),
                              const SizedBox(height: 16),
                              if (_error != null)
                                _ErrorPanel(
                                  palette: palette,
                                  message: _error!,
                                  onRetry: _cargarSucursales,
                                )
                              else if (_cargandoSucursales || _cargandoMedios)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 80),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              else if (_sucursales.isEmpty)
                                _EmptyPanel(
                                  palette: palette,
                                  icon: Icons.store_mall_directory_outlined,
                                  title: 'No hay sucursales disponibles',
                                  message: 'Registra una sucursal antes de parametrizar sus medios de pago.',
                                )
                              else if (_medios.isEmpty)
                                _EmptyPanel(
                                  palette: palette,
                                  icon: Icons.payments_outlined,
                                  title: 'No hay medios de pago en el catálogo',
                                  message: 'La sucursal no tiene opciones disponibles para parametrizar.',
                                )
                              else ...[
                                _SucursalResumen(
                                  palette: palette,
                                  sucursal: sucursal,
                                  total: _medios.length,
                                  activos: activos,
                                  conQr: conQr,
                                ),
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final columns = constraints.maxWidth >= 1080
                                        ? 3
                                        : constraints.maxWidth >= 700
                                            ? 2
                                            : 1;
                                    final spacing = 14.0;
                                    final width = columns == 1
                                        ? constraints.maxWidth
                                        : (constraints.maxWidth - (spacing * (columns - 1))) / columns;
                                    return Wrap(
                                      spacing: spacing,
                                      runSpacing: spacing,
                                      children: [
                                        for (final medio in _medios)
                                          SizedBox(
                                            width: width,
                                            child: _MedioPagoSucursalCard(
                                              palette: palette,
                                              medio: medio,
                                              saving: medio.mepaId != null && _guardando.contains(medio.mepaId),
                                              onToggle: (value) => _actualizarMedio(medio, estado: value ? 1 : 0),
                                              onPickQr: () => _cargarQr(medio),
                                              onRemoveQr: () => _quitarQr(medio),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlHeader extends StatelessWidget {
  const _ControlHeader({
    required this.palette,
    required this.sucursales,
    required this.selectedSucursalId,
    required this.loading,
    required this.disabled,
    required this.onChanged,
  });

  final AppPalette palette;
  final List<SucursalesResponseModel> sucursales;
  final int? selectedSucursalId;
  final bool loading;
  final bool disabled;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: palette.glassGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.translucentBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final title = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.account_balance_wallet_rounded, color: palette.onPrimary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control de medios de pago',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: palette.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Activa las opciones disponibles y carga el QR específico de cada sucursal.',
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          );

          final selector = DropdownButtonFormField<int>(
            value: selectedSucursalId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Sucursal a administrar',
              prefixIcon: const Icon(Icons.store_rounded),
              filled: true,
              fillColor: palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.72),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            items: sucursales
                .where((item) => item.sucuId != null)
                .map(
                  (item) => DropdownMenuItem<int>(
                    value: item.sucuId,
                    child: Text(
                      '${item.sucuNombre ?? 'Sucursal ${item.sucuId}'}${item.sucuEstado == 1 ? '' : ' · Inactiva'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: loading || disabled ? null : onChanged,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 18), selector],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 22),
              SizedBox(width: 360, child: selector),
            ],
          );
        },
      ),
    );
  }
}

class _SucursalResumen extends StatelessWidget {
  const _SucursalResumen({
    required this.palette,
    required this.sucursal,
    required this.total,
    required this.activos,
    required this.conQr,
  });

  final AppPalette palette;
  final SucursalesResponseModel? sucursal;
  final int total;
  final int activos;
  final int conQr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final branch = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sucursal?.sucuNombre ?? 'Sucursal seleccionada',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: palette.textPrimary,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                [sucursal?.sucuCodigoInterno, sucursal?.sucuDireccion]
                    .where((value) => value != null && value!.trim().isNotEmpty)
                    .join(' · '),
                style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          );
          final metrics = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricPill(palette: palette, icon: Icons.list_alt_rounded, label: '$total disponibles'),
              _MetricPill(palette: palette, icon: Icons.check_circle_rounded, label: '$activos activos', success: true),
              _MetricPill(palette: palette, icon: Icons.qr_code_2_rounded, label: '$conQr con QR'),
            ],
          );
          if (compact) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [branch, const SizedBox(height: 14), metrics]);
          }
          return Row(children: [Expanded(child: branch), const SizedBox(width: 16), metrics]);
        },
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.palette, required this.icon, required this.label, this.success = false});

  final AppPalette palette;
  final IconData icon;
  final String label;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? palette.success : palette.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MedioPagoSucursalCard extends StatelessWidget {
  const _MedioPagoSucursalCard({
    required this.palette,
    required this.medio,
    required this.saving,
    required this.onToggle,
    required this.onPickQr,
    required this.onRemoveQr,
  });

  final AppPalette palette;
  final MediosPagoResponseModel medio;
  final bool saving;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickQr;
  final VoidCallback onRemoveQr;

  @override
  Widget build(BuildContext context) {
    final active = medio.mepaEstado == 1;
    final qr = (medio.mepaQr ?? '').trim();
    final statusColor = active ? palette.success : palette.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.99),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: active ? palette.secondary.withOpacity(0.34) : palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(active ? 0.7 : 0.35), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(_iconFor(medio.mepaNombre), color: palette.secondary, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medio.mepaNombre ?? 'Medio de pago',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      medio.mepaDescripcion ?? 'Sin descripción',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (saving)
                const SizedBox(width: 34, height: 34, child: Padding(padding: EdgeInsets.all(7), child: CircularProgressIndicator(strokeWidth: 2)))
              else
                Switch(value: active, onChanged: onToggle),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(active ? Icons.check_circle_rounded : Icons.pause_circle_rounded, color: statusColor, size: 18),
              const SizedBox(width: 7),
              Text(
                active ? 'Activo en esta sucursal' : 'Inactivo en esta sucursal',
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 190,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.background.withOpacity(palette.darkBackground ? 0.42 : 0.68),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.cardBorder),
            ),
            child: qr.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 56, color: palette.textSecondary.withOpacity(0.55)),
                      const SizedBox(height: 8),
                      Text('Sin QR configurado', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800)),
                    ],
                  )
                : _QrImage(value: qr, palette: palette),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: saving ? null : onPickQr,
                  icon: Icon(qr.isEmpty ? Icons.upload_rounded : Icons.sync_rounded),
                  label: Text(qr.isEmpty ? 'Cargar QR' : 'Reemplazar QR'),
                ),
              ),
              if (qr.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Quitar QR de esta sucursal',
                  onPressed: saving ? null : onRemoveQr,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QrImage extends StatelessWidget {
  const _QrImage({required this.value, required this.palette});

  final String value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeImage(value);
    final image = bytes != null
        ? Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: _errorBuilder)
        : Image.network(value, fit: BoxFit.contain, errorBuilder: _errorBuilder);
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: ColoredBox(color: Colors.white, child: Padding(padding: const EdgeInsets.all(8), child: image)));
  }

  Widget _errorBuilder(BuildContext context, Object error, StackTrace? stackTrace) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, color: palette.textSecondary, size: 38),
          const SizedBox(height: 6),
          Text('No se pudo mostrar el QR', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.palette, required this.message, required this.onRetry});

  final AppPalette palette;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _EmptyPanel(
      palette: palette,
      icon: Icons.error_outline_rounded,
      title: 'No fue posible cargar la configuración',
      message: message,
      action: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar')),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.palette, required this.icon, required this.title, required this.message, this.action});

  final AppPalette palette;
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: palette.secondary),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

List<SucursalesResponseModel> _parseSucursales(Object? json) {
  final items = json is List ? json : const [];
  return items
      .whereType<Map>()
      .map((item) => SucursalesResponseModel.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

List<MediosPagoResponseModel> _parseMedios(Object? json) {
  final items = json is List ? json : const [];
  return items
      .whereType<Map>()
      .map((item) => MediosPagoResponseModel.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

Uint8List? _decodeImage(String value) {
  try {
    if (value.startsWith('data:image')) {
      final comma = value.indexOf(',');
      if (comma < 0) return null;
      return base64Decode(value.substring(comma + 1));
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return base64Decode(value);
    }
  } catch (_) {
    return null;
  }
  return null;
}

IconData _iconFor(String? name) {
  final normalized = (name ?? '').toLowerCase();
  if (normalized.contains('efect')) return Icons.payments_rounded;
  if (normalized.contains('tarjet')) return Icons.credit_card_rounded;
  if (normalized.contains('transfer')) return Icons.swap_horiz_rounded;
  if (normalized.contains('nequi') || normalized.contains('daviplata') || normalized.contains('móvil') || normalized.contains('movil')) {
    return Icons.phone_android_rounded;
  }
  if (normalized.contains('qr')) return Icons.qr_code_2_rounded;
  return Icons.account_balance_wallet_rounded;
}

String _mensajeError(Object error) {
  final value = error.toString().trim();
  return value.replaceFirst(RegExp(r'^(Exception|ApiException|NetworkException):\s*'), '');
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
