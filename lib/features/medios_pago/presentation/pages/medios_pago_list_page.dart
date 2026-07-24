import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_control_metrics.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../sucursales/data/models/sucursales_response_model.dart';
import '../../data/models/medios_pago_response_model.dart';

enum _PaymentFilter { all, active, inactive, withoutQr }

class MediosPagoListPage extends ConsumerStatefulWidget {
  const MediosPagoListPage({super.key});

  @override
  ConsumerState<MediosPagoListPage> createState() => _MediosPagoListPageState();
}

class _MediosPagoListPageState extends ConsumerState<MediosPagoListPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _saving = <int>{};

  List<SucursalesResponseModel> _branches = const [];
  List<MediosPagoResponseModel> _methods = const [];
  int? _branchId;
  bool _loadingBranches = true;
  bool _loadingMethods = false;
  String? _error;
  String _query = '';
  _PaymentFilter _filter = _PaymentFilter.all;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadBranches);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    if (mounted) {
      setState(() {
        _loadingBranches = true;
        _error = null;
      });
    }
    try {
      final response = await ref.read(apiClientProvider).get<List<SucursalesResponseModel>>(
        '/api/v1/mediospago/sucursales',
        (json) => _parseBranches(json),
      );
      final branches = response.data ?? const <SucursalesResponseModel>[];
      final enabled = branches.where((item) => item.sucuEstado == 1 && item.sucuId != null).toList(growable: false);
      final usable = enabled.isNotEmpty ? enabled : branches.where((item) => item.sucuId != null).toList(growable: false);
      final selected = _branchId != null && usable.any((item) => item.sucuId == _branchId)
          ? _branchId
          : (usable.isEmpty ? null : usable.first.sucuId);
      if (!mounted) return;
      setState(() {
        _branches = usable;
        _branchId = selected;
        _loadingBranches = false;
      });
      if (selected != null) await _loadMethods(selected);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingBranches = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _loadMethods(int branchId) async {
    setState(() {
      _loadingMethods = true;
      _error = null;
      _methods = const [];
    });
    try {
      final response = await ref.read(apiClientProvider).get<List<MediosPagoResponseModel>>(
        '/api/v1/mediospago/sucursal/$branchId',
        (json) => _parseMethods(json),
      );
      if (!mounted || branchId != _branchId) return;
      setState(() {
        _methods = response.data ?? const <MediosPagoResponseModel>[];
        _loadingMethods = false;
      });
    } catch (error) {
      if (!mounted || branchId != _branchId) return;
      setState(() {
        _loadingMethods = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _changeBranch(int? value) async {
    if (value == null || value == _branchId || _saving.isNotEmpty) return;
    setState(() {
      _branchId = value;
      _query = '';
      _filter = _PaymentFilter.all;
      _searchController.clear();
    });
    await _loadMethods(value);
  }

  Future<void> _updateMethod(
    MediosPagoResponseModel method, {
    int? status,
    String? qr,
    bool sendQr = false,
  }) async {
    final branchId = _branchId;
    final methodId = method.mepaId;
    if (branchId == null || methodId == null || _saving.contains(methodId)) return;
    setState(() => _saving.add(methodId));
    try {
      final body = <String, dynamic>{
        'mepaNombre': method.mepaNombre,
        'mepaDescripcion': method.mepaDescripcion,
        'mepaEstado': status ?? method.mepaEstado ?? 0,
        if (sendQr) 'mepaQr': qr ?? '',
      };
      final response = await ref.read(apiClientProvider).put<MediosPagoResponseModel>(
        '/api/v1/mediospago/sucursal/$branchId/$methodId',
        body,
        (json) => MediosPagoResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
      );
      final updated = response.data;
      if (!mounted || updated == null || branchId != _branchId) return;
      setState(() {
        _methods = _methods.map((item) => item.mepaId == methodId ? updated : item).toList(growable: false);
      });
    } catch (error) {
      if (mounted) _showMessage(_message(error), error: true);
    } finally {
      if (mounted) setState(() => _saving.remove(methodId));
    }
  }

  Future<void> _pickQr(MediosPagoResponseModel method) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showMessage('No fue posible leer la imagen seleccionada.', error: true);
      return;
    }
    if (bytes.length > 4 * 1024 * 1024) {
      _showMessage('El QR no puede superar 4 MB.', error: true);
      return;
    }
    final extension = (file.extension ?? 'png').toLowerCase();
    final mime = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/png',
    };
    await _updateMethod(method, qr: 'data:$mime;base64,${base64Encode(bytes)}', sendQr: true);
    if (mounted) _showMessage('QR actualizado');
  }

  Future<void> _removeQr(MediosPagoResponseModel method) async {
    final confirmed = await _confirmRemoveQr(method.mepaNombre ?? 'este medio');
    if (!confirmed) return;
    await _updateMethod(method, qr: '', sendQr: true);
    if (mounted) _showMessage('QR eliminado');
  }

  Future<bool> _confirmRemoveQr(String name) async {
    final palette = ref.read(selectedAppPaletteProvider);
    return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.56),
          builder: (context) => Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 430),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(palette.radius(26)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.28), blurRadius: 30, offset: const Offset(0, 12))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.14), borderRadius: BorderRadius.circular(15)),
                        child: Icon(Icons.qr_code_2_rounded, color: Colors.red.shade400),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Quitar código QR',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Se eliminará el QR configurado para $name en esta sucursal.',
                    style: TextStyle(color: palette.textSecondary, height: 1.35, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar'))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Quitar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  Future<void> _previewQr(MediosPagoResponseModel method) async {
    final qr = (method.mepaQr ?? '').trim();
    if (qr.isEmpty) return;
    final palette = ref.read(selectedAppPaletteProvider);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (context) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(palette.radius(28)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.32), blurRadius: 34, offset: const Offset(0, 14))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(_iconFor(method.mepaNombre), color: palette.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      method.mepaNombre ?? 'Medio de pago',
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(palette.radius(20)),
                  child: ColoredBox(
                    color: Colors.white,
                    child: Padding(padding: const EdgeInsets.all(16), child: _QrImage(value: qr, palette: palette)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _pickQr(method);
                },
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Reemplazar QR'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  List<MediosPagoResponseModel> get _visibleMethods {
    final query = _query.trim().toLowerCase();
    final result = _methods.where((method) {
      final qr = (method.mepaQr ?? '').trim();
      final matchesQuery = query.isEmpty || '${method.mepaNombre ?? ''} ${method.mepaDescripcion ?? ''}'.toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _PaymentFilter.all => true,
        _PaymentFilter.active => method.mepaEstado == 1,
        _PaymentFilter.inactive => method.mepaEstado != 1,
        _PaymentFilter.withoutQr => qr.isEmpty,
      };
      return matchesQuery && matchesFilter;
    }).toList(growable: false);
    result.sort((a, b) {
      final activeCompare = (b.mepaEstado ?? 0).compareTo(a.mepaEstado ?? 0);
      if (activeCompare != 0) return activeCompare;
      return (a.mepaNombre ?? '').toLowerCase().compareTo((b.mepaNombre ?? '').toLowerCase());
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final branch = _branches.where((item) => item.sucuId == _branchId).firstOrNull;
    final active = _methods.where((item) => item.mepaEstado == 1).length;
    final withQr = _methods.where((item) => (item.mepaQr ?? '').trim().isNotEmpty).length;
    final visible = _visibleMethods;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: _loadBranches,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: const Align(
                            alignment: Alignment.centerLeft,
                            child: _BackToParametersButton(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: _Toolbar(
                            palette: palette,
                            controller: _searchController,
                            branches: _branches,
                            branchId: _branchId,
                            disabled: _loadingBranches || _saving.isNotEmpty,
                            query: _query,
                            filter: _filter,
                            total: _methods.length,
                            visible: visible.length,
                            active: active,
                            withQr: withQr,
                            onBranchChanged: _changeBranch,
                            onQueryChanged: (value) => setState(() => _query = value),
                            onClearQuery: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            onFilterChanged: (value) => setState(() => _filter = value),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: _buildContent(palette, branch, visible),
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

  Widget _buildContent(
    AppPalette palette,
    SucursalesResponseModel? branch,
    List<MediosPagoResponseModel> visible,
  ) {
    if (_loadingBranches || _loadingMethods) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 80), child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return _StatePanel(
        palette: palette,
        icon: Icons.error_outline_rounded,
        title: 'No fue posible cargar los medios de pago',
        message: _error!,
        action: FilledButton.icon(onPressed: _loadBranches, icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar')),
      );
    }
    if (_branches.isEmpty) {
      return _StatePanel(
        palette: palette,
        icon: Icons.store_mall_directory_outlined,
        title: 'No hay sucursales disponibles',
        message: 'Registra una sucursal antes de configurar los medios de pago.',
      );
    }
    if (_methods.isEmpty) {
      return _StatePanel(
        palette: palette,
        icon: Icons.payments_outlined,
        title: 'No hay medios de pago',
        message: 'El catálogo no tiene medios disponibles para esta sucursal.',
      );
    }
    if (visible.isEmpty) {
      return _StatePanel(
        palette: palette,
        icon: Icons.search_off_rounded,
        title: 'No encontramos coincidencias',
        message: 'Cambia el filtro o limpia la búsqueda.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_branches.length == 1 && branch != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.store_rounded, size: 18, color: palette.secondary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    branch.sucuNombre ?? 'Sucursal',
                    style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1040
                ? 3
                : constraints.maxWidth >= 680
                    ? 2
                    : 1;
            const spacing = 12.0;
            final width = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final method in visible)
                  SizedBox(
                    width: width,
                    child: _PaymentMethodCard(
                      palette: palette,
                      method: method,
                      saving: method.mepaId != null && _saving.contains(method.mepaId),
                      onToggle: (value) => _updateMethod(method, status: value ? 1 : 0),
                      onPickQr: () => _pickQr(method),
                      onRemoveQr: () => _removeQr(method),
                      onPreviewQr: () => _previewQr(method),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.palette,
    required this.controller,
    required this.branches,
    required this.branchId,
    required this.disabled,
    required this.query,
    required this.filter,
    required this.total,
    required this.visible,
    required this.active,
    required this.withQr,
    required this.onBranchChanged,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onFilterChanged,
  });

  final AppPalette palette;
  final TextEditingController controller;
  final List<SucursalesResponseModel> branches;
  final int? branchId;
  final bool disabled;
  final String query;
  final _PaymentFilter filter;
  final int total;
  final int visible;
  final int active;
  final int withQr;
  final ValueChanged<int?> onBranchChanged;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<_PaymentFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: palette.panelGradient(tint: palette.secondary),
        borderRadius: BorderRadius.circular(palette.radius(22)),
        boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 9))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final search = TextField(
                controller: controller,
                onChanged: onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar medio de pago',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty ? null : IconButton(onPressed: onClearQuery, icon: const Icon(Icons.close_rounded)),
                ).compactFilter(),
              );
              final branchSelector = branches.length > 1
                  ? DropdownButtonFormField<int>(
                      value: branchId,
                      isExpanded: true,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.store_rounded), labelText: 'Sucursal').compactFilter(),
                      items: branches
                          .where((item) => item.sucuId != null)
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item.sucuId,
                              child: Text(item.sucuNombre ?? 'Sucursal ${item.sucuId}', overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: disabled ? null : onBranchChanged,
                    )
                  : null;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [search, if (branchSelector != null) ...[const SizedBox(height: 10), branchSelector]],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  if (branchSelector != null) ...[const SizedBox(width: 12), SizedBox(width: 300, child: branchSelector)],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  palette: palette,
                  selected: filter == _PaymentFilter.all,
                  icon: Icons.apps_rounded,
                  label: 'Todos $total',
                  onTap: () => onFilterChanged(_PaymentFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  palette: palette,
                  selected: filter == _PaymentFilter.active,
                  icon: Icons.check_circle_rounded,
                  label: 'Activos $active',
                  positive: true,
                  onTap: () => onFilterChanged(_PaymentFilter.active),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  palette: palette,
                  selected: filter == _PaymentFilter.inactive,
                  icon: Icons.pause_circle_rounded,
                  label: 'Inactivos ${total - active}',
                  onTap: () => onFilterChanged(_PaymentFilter.inactive),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  palette: palette,
                  selected: filter == _PaymentFilter.withoutQr,
                  icon: Icons.qr_code_2_rounded,
                  label: 'Sin QR ${total - withQr}',
                  onTap: () => onFilterChanged(_PaymentFilter.withoutQr),
                ),
                if (visible != total) ...[
                  const SizedBox(width: 10),
                  Text('$visible visibles', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.palette,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.positive = false,
  });

  final AppPalette palette;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? palette.success : palette.secondary;
    return Material(
      color: selected ? color.withOpacity(0.18) : palette.background.withOpacity(palette.darkBackground ? 0.30 : 0.58),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 17, color: selected ? color : palette.textSecondary),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(color: selected ? palette.textPrimary : palette.textSecondary, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.palette,
    required this.method,
    required this.saving,
    required this.onToggle,
    required this.onPickQr,
    required this.onRemoveQr,
    required this.onPreviewQr,
  });

  final AppPalette palette;
  final MediosPagoResponseModel method;
  final bool saving;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickQr;
  final VoidCallback onRemoveQr;
  final VoidCallback onPreviewQr;

  @override
  Widget build(BuildContext context) {
    final active = method.mepaEstado == 1;
    final qr = (method.mepaQr ?? '').trim();
    final statusColor = active ? palette.success : palette.textSecondary;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: active ? 1 : 0.76,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: palette.panelGradient(tint: active ? palette.secondary : palette.textSecondary),
          borderRadius: BorderRadius.circular(palette.radius(22)),
          boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(active ? 0.38 : 0.22), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: palette.secondary.withOpacity(0.13), borderRadius: BorderRadius.circular(16)),
                  child: Icon(_iconFor(method.mepaNombre), color: palette.secondary, size: 25),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.mepaNombre ?? 'Medio de pago',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        active ? 'Disponible para cobrar' : 'No disponible para cobrar',
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (saving)
                  const SizedBox(width: 36, height: 36, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                else
                  Switch(value: active, onChanged: onToggle),
              ],
            ),
            if ((method.mepaDescripcion ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                method.mepaDescripcion!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textSecondary, height: 1.3, fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.background.withOpacity(palette.darkBackground ? 0.30 : 0.58),
                borderRadius: BorderRadius.circular(palette.radius(18)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: qr.isEmpty ? null : onPreviewQr,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: qr.isEmpty ? palette.secondary.withOpacity(0.10) : Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: qr.isEmpty
                          ? Icon(Icons.qr_code_2_rounded, color: palette.textSecondary, size: 34)
                          : _QrImage(value: qr, palette: palette),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          qr.isEmpty ? 'Sin QR configurado' : 'QR configurado',
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          qr.isEmpty ? 'Carga el código de esta sucursal.' : 'Toca la miniatura para ampliarlo.',
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: saving ? null : onPickQr,
                    icon: Icon(qr.isEmpty ? Icons.upload_rounded : Icons.sync_rounded),
                    label: Text(qr.isEmpty ? 'Cargar QR' : 'Cambiar QR'),
                  ),
                ),
                if (qr.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Quitar QR',
                    onPressed: saving ? null : onRemoveQr,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ],
            ),
          ],
        ),
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
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, __, ___) => _fallback());
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(value, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _fallback());
    }
    return _fallback();
  }

  Widget _fallback() => Center(child: Icon(Icons.broken_image_outlined, color: palette.textSecondary, size: 28));
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.palette, required this.icon, required this.title, required this.message, this.action});

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
        gradient: palette.panelGradient(tint: palette.secondary),
        borderRadius: BorderRadius.circular(palette.radius(24)),
        boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(0.30), blurRadius: 20, offset: const Offset(0, 9))],
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

List<SucursalesResponseModel> _parseBranches(Object? json) {
  final items = json is List ? json : const [];
  return items
      .whereType<Map>()
      .map((item) => SucursalesResponseModel.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

List<MediosPagoResponseModel> _parseMethods(Object? json) {
  final items = json is List ? json : const [];
  return items
      .whereType<Map>()
      .map((item) => MediosPagoResponseModel.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

Uint8List? _decodeImage(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return null;
  try {
    if (clean.startsWith('data:image')) {
      final comma = clean.indexOf(',');
      if (comma < 0) return null;
      return base64Decode(clean.substring(comma + 1));
    }
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      return base64Decode(clean);
    }
  } catch (_) {
    return null;
  }
  return null;
}

IconData _iconFor(String? name) {
  final normalized = (name ?? '').toLowerCase();
  if (normalized.contains('efect')) return Icons.payments_rounded;
  if (normalized.contains('nequi')) return Icons.phone_android_rounded;
  if (normalized.contains('daviplata')) return Icons.smartphone_rounded;
  if (normalized.contains('tarjeta') || normalized.contains('datafono')) return Icons.credit_card_rounded;
  if (normalized.contains('transfer')) return Icons.account_balance_rounded;
  if (normalized.contains('credito')) return Icons.receipt_long_rounded;
  return Icons.account_balance_wallet_rounded;
}

String _message(Object error) {
  final text = error.toString();
  return text.replaceFirst(RegExp(r'^Exception:\s*'), '').trim().isEmpty ? 'Ocurrió un error inesperado.' : text.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
}

class _BackToParametersButton extends StatelessWidget {
  const _BackToParametersButton();

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => context.go('/tablas_parametricas'),
      icon: const Icon(Icons.arrow_back_rounded),
      label: const Text('Parámetros'),
    );
  }
}

