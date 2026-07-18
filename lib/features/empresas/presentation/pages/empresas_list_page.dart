import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/module_visuals.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../data/models/empresas_response_model.dart';

/// Listado especializado de empresas.
///
/// Se usa una vista propia para evitar mostrar campos técnicos y controlar
/// exactamente las columnas visibles solicitadas por negocio:
/// Nombre comercial, razón social, tipo de identificación, identificación,
/// país/ciudad, teléfono y correo electrónico.
class EmpresasListPage extends ConsumerStatefulWidget {
  const EmpresasListPage({super.key});

  @override
  ConsumerState<EmpresasListPage> createState() => _EmpresasListPageState();
}

class _EmpresasListPageState extends ConsumerState<EmpresasListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tableHorizontalController = ScrollController();

  List<EmpresasResponseModel> _empresas = const <EmpresasResponseModel>[];
  Map<int, String> _tiposIdentificacion = const <int, String>{};
  Map<int, Map<String, dynamic>> _ciudades = const <int, Map<String, dynamic>>{};
  Map<int, Map<String, dynamic>> _regiones = const <int, Map<String, dynamic>>{};
  Map<int, String> _paises = const <int, String>{};

  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableHorizontalController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final apiClient = ref.read(apiClientProvider);

      final results = await Future.wait<Object>([
        apiClient.get<List<EmpresasResponseModel>>(
          ApiPaths.empresas,
          (json) => (json as List? ?? const <Object?>[])
              .whereType<Map>()
              .map((item) => EmpresasResponseModel.fromJson(Map<String, dynamic>.from(item)))
              .toList(),
        ),
        apiClient.get<Map<int, String>>(
          ApiPaths.tiposidentificacion,
          (json) => _toLabelMap(json, 'tiidId', ['tiidNombre', 'tiidDescripcion']),
        ),
        apiClient.get<Map<int, Map<String, dynamic>>>(
          ApiPaths.ciudades,
          (json) => _toRawMap(json, 'ciudId'),
        ),
        apiClient.get<Map<int, Map<String, dynamic>>>(
          ApiPaths.regiones,
          (json) => _toRawMap(json, 'regiId'),
        ),
        apiClient.get<Map<int, String>>(
          ApiPaths.paises,
          (json) => _toLabelMap(json, 'paisId', ['paisNombre', 'paisCodigo']),
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _empresas = (results[0] as dynamic).data as List<EmpresasResponseModel>? ?? const <EmpresasResponseModel>[];
        _tiposIdentificacion = (results[1] as dynamic).data as Map<int, String>? ?? const <int, String>{};
        _ciudades = (results[2] as dynamic).data as Map<int, Map<String, dynamic>>? ?? const <int, Map<String, dynamic>>{};
        _regiones = (results[3] as dynamic).data as Map<int, Map<String, dynamic>>? ?? const <int, Map<String, dynamic>>{};
        _paises = (results[4] as dynamic).data as Map<int, String>? ?? const <int, String>{};
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static Map<int, String> _toLabelMap(Object? json, String idField, List<String> displayFields) {
    final result = <int, String>{};
    final items = json is List ? json : const <Object?>[];

    for (final item in items.whereType<Map>()) {
      final raw = Map<String, dynamic>.from(item);
      final id = (raw[idField] as num?)?.toInt();
      if (id == null) continue;

      final parts = displayFields
          .map((field) => raw[field]?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toList();

      result[id] = parts.isEmpty ? '-' : parts.join(' - ');
    }

    return result;
  }

  static Map<int, Map<String, dynamic>> _toRawMap(Object? json, String idField) {
    final result = <int, Map<String, dynamic>>{};
    final items = json is List ? json : const <Object?>[];

    for (final item in items.whereType<Map>()) {
      final raw = Map<String, dynamic>.from(item);
      final id = (raw[idField] as num?)?.toInt();
      if (id != null) result[id] = raw;
    }

    return result;
  }

  List<EmpresasResponseModel> get _filteredEmpresas {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _empresas;

    return _empresas.where((empresa) {
      final text = [
        empresa.empreNombreComercial,
        empresa.emprRazonSocial,
        _tipoIdentificacion(empresa.tiidId),
        empresa.emprIdentificacion,
        _paisCiudad(empresa),
        empresa.emprTelefono,
        empresa.emprCorreoElectronico,
      ].join(' ').toLowerCase();

      return text.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final empresas = _filteredEmpresas;
    final palette = ref.watch(selectedAppPaletteProvider);
    final showTable = MediaQuery.sizeOf(context).width >= 820;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'empresas-nueva-empresa-fab',
        backgroundColor: palette.actionColor,
        foregroundColor: palette.onAction,
        onPressed: _loading ? null : () => _safeGo('/empresas/nuevo'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear empresa'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: _loadData,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: _EmpresasToolbar(
                          total: _empresas.length,
                          visible: empresas.length,
                          controller: _searchController,
                          palette: palette,
                          loading: _loading,
                          onChanged: (value) => setState(() => _search = value),
                          onRefresh: _loadData,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _loading
                      ? const Padding(padding: EdgeInsets.all(32), child: AppLoader())
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                          child: empresas.isEmpty
                              ? _emptyState(palette)
                              : showTable
                                  ? _desktopTable(empresas, palette)
                                  : _mobileCards(empresas, palette),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text, AppPalette palette, {required double width, bool alignEnd = false}) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: palette.textPrimary),
        ),
      ),
    );
  }

  Widget _desktopTable(List<EmpresasResponseModel> empresas, AppPalette palette) {
    const double minTableWidth = 1180;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final visibleWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : minTableWidth;
            final effectiveWidth = minTableWidth < visibleWidth ? visibleWidth : minTableWidth;
            return Scrollbar(
              controller: _tableHorizontalController,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _tableHorizontalController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 14),
                child: SizedBox(
                  width: effectiveWidth,
                  child: DataTable(
                    headingRowHeight: 58,
                    dataRowMinHeight: 58,
                    dataRowMaxHeight: 72,
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    headingRowColor: WidgetStatePropertyAll(palette.secondary.withOpacity(palette.darkBackground ? 0.12 : 0.07)),
                    headingTextStyle: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary),
                    dataTextStyle: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary),
                    columns: [
                      DataColumn(label: _tableHeader('Nombre comercial', palette, width: 145)),
                      DataColumn(label: _tableHeader('Razón social', palette, width: 150)),
                      DataColumn(label: _tableHeader('Tipo de identificación', palette, width: 155)),
                      DataColumn(label: _tableHeader('Identificación', palette, width: 105)),
                      DataColumn(label: _tableHeader('País / ciudad', palette, width: 145)),
                      DataColumn(label: _tableHeader('Teléfono', palette, width: 105)),
                      DataColumn(label: _tableHeader('Correo electrónico', palette, width: 160)),
                      DataColumn(label: _tableHeader('Acciones', palette, width: 120, alignEnd: true)),
                    ],
                    rows: [
                      for (final empresa in empresas)
                        DataRow(
                          onSelectChanged: empresa.emprId == null ? null : (_) => _safeGo('/empresas/${empresa.emprId}'),
                          cells: [
                            DataCell(SizedBox(width: 145, child: Text(_text(empresa.empreNombreComercial), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)))),
                            DataCell(SizedBox(width: 150, child: Text(_text(empresa.emprRazonSocial), maxLines: 2, overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 155, child: Text(_tipoIdentificacion(empresa.tiidId), maxLines: 2, overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 105, child: Text(_text(empresa.emprIdentificacion), overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 145, child: Text(_paisCiudad(empresa), maxLines: 2, overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 105, child: Text(_text(empresa.emprTelefono), overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 160, child: Text(_text(empresa.emprCorreoElectronico), maxLines: 2, overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 120, child: _actions(empresa, palette))),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _mobileCards(List<EmpresasResponseModel> empresas, AppPalette palette) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: empresas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final empresa = empresas[index];
        return Card(
          color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: palette.cardBorder)),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: empresa.emprId == null ? null : () => _safeGo('/empresas/${empresa.emprId}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(Icons.business_rounded, color: palette.onPrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_text(empresa.empreNombreComercial), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: palette.textPrimary)),
                            const SizedBox(height: 2),
                            Text(_text(empresa.emprRazonSocial), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _mobileInfo('Tipo de identificación', _tipoIdentificacion(empresa.tiidId), palette),
                  _mobileInfo('Identificación', _text(empresa.emprIdentificacion), palette),
                  _mobileInfo('País / ciudad', _paisCiudad(empresa), palette),
                  _mobileInfo('Teléfono', _text(empresa.emprTelefono), palette),
                  _mobileInfo('Correo electrónico', _text(empresa.emprCorreoElectronico), palette),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: _actions(empresa, palette)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mobileInfo(String label, String value, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 135, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: palette.textSecondary))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: palette.textPrimary))),
        ],
      ),
    );
  }

  Widget _actions(EmpresasResponseModel empresa, AppPalette palette) {
    final id = empresa.emprId;
    Widget action({required String tooltip, required VoidCallback? onPressed, required IconData icon, required Color color}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: IconButton.filledTonal(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(backgroundColor: color.withOpacity(0.12), foregroundColor: color),
          icon: Icon(icon, size: 19),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        action(tooltip: 'Visualizar', onPressed: id == null ? null : () => _safeGo('/empresas/$id'), icon: Icons.visibility_rounded, color: palette.secondary),
        action(tooltip: 'Modificar', onPressed: id == null ? null : () => _safeGo('/empresas/$id/editar'), icon: Icons.edit_rounded, color: palette.primary),
        action(tooltip: 'Eliminar', onPressed: id == null ? null : () => _confirmDelete(empresa), icon: Icons.delete_outline_rounded, color: AppColors.danger),
      ],
    );
  }

  void _safeGo(String location) {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 1), () {
        if (mounted) context.go(location);
      });
    });
  }

  Future<void> _confirmDelete(EmpresasResponseModel empresa) async {
    final id = empresa.emprId;
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar empresa'),
        content: Text('¿Deseas eliminar o inactivar ${_text(empresa.empreNombreComercial)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Aceptar')),
        ],
      ),
    );

    if (confirm != true) return;

    await ref.read(apiClientProvider).delete<void>('${ApiPaths.empresas}/$id', (_) {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empresa eliminada correctamente')));
    await _loadData();
  }

  Widget _emptyState(AppPalette palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 54, color: palette.textSecondary.withOpacity(0.75)),
          const SizedBox(height: 12),
          Text('No hay empresas para mostrar', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: palette.textPrimary)),
          const SizedBox(height: 4),
          Text('Ajusta la búsqueda o registra una nueva empresa.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: palette.textSecondary)),
        ],
      ),
    );
  }

  String _tipoIdentificacion(int? id) {
    if (id == null) return '-';
    return _tiposIdentificacion[id] ?? '-';
  }

  String _paisCiudad(EmpresasResponseModel empresa) {
    final ciudad = _ciudades[empresa.ciudId];
    final ciudadNombre = ciudad?['ciudNombre']?.toString().trim() ?? '';
    final regiId = (ciudad?['regiId'] as num?)?.toInt();
    final region = _regiones[regiId];
    final paisId = (region?['paisId'] as num?)?.toInt();
    final paisNombre = _paises[paisId] ?? '';

    if (paisNombre.isNotEmpty && ciudadNombre.isNotEmpty) return '$paisNombre / $ciudadNombre';
    if (ciudadNombre.isNotEmpty) return ciudadNombre;

    final paisTelefono = _paises[empresa.paisIdtelefono] ?? '';
    if (paisTelefono.isNotEmpty) return paisTelefono;

    return '-';
  }

  String _text(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '-' : text;
  }
}

class _EmpresasToolbar extends StatelessWidget {
  const _EmpresasToolbar({
    required this.total,
    required this.visible,
    required this.controller,
    required this.palette,
    required this.loading,
    required this.onChanged,
    required this.onRefresh,
  });

  final int total;
  final int visible;
  final TextEditingController controller;
  final AppPalette palette;
  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.secondary.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final info = Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.business_center_rounded, color: palette.onPrimary, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Administración de empresas', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
                    const SizedBox(height: 3),
                    Text('Gestiona los negocios, su identificación, ubicación y datos de contacto.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: palette.secondary.withOpacity(0.22))),
                child: Text('$visible/$total', style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                onPressed: loading ? null : onRefresh,
                tooltip: 'Actualizar',
                icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded),
              ),
            ],
          );
          final search = TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Buscar por nombre, identificación, ciudad, teléfono o correo...',
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          );
          if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 14), search]);
          return Row(children: [Expanded(flex: 5, child: info), const SizedBox(width: 16), Expanded(flex: 4, child: search)]);
        },
      ),
    );
  }
}
