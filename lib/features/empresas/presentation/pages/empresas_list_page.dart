import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/module_visuals.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_loader.dart';
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
    if (_loading) return const AppLoader();

    final empresas = _filteredEmpresas;
    final visual = ModuleVisuals.byKey('empresas');
    final showTable = MediaQuery.sizeOf(context).width >= 820;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'empresas-nueva-empresa-fab',
        onPressed: () => _safeGo('/empresas/nuevo'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 218,
            title: const Text('Empresas'),
            actions: [
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _header(empresas.length, visual),
            ),
          ),
          SliverToBoxAdapter(
            child: showTable ? _desktopTable(empresas, visual) : _mobileCards(empresas, visual),
          ),
        ],
      ),
    );
  }

  Widget _header(int count, ModuleVisual visual) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [visual.color.withOpacity(0.18), AppColors.accentSoft, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 58, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: visual.color,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: visual.color.withOpacity(0.25),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(visual.icon, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Empresas', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                        SizedBox(height: 2),
                        Text('Negocios o tenants registrados', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: visual.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: visual.color.withOpacity(0.22)),
                    ),
                    child: Text('$count/${_empresas.length}', style: TextStyle(color: visual.color, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Buscar por nombre, razón social, identificación, ciudad, teléfono o correo...',
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar(ModuleVisual visual) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Buscar por nombre, razón social, identificación, ciudad, teléfono o correo...',
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: 'Recargar',
            onPressed: _loadData,
            style: IconButton.styleFrom(
              backgroundColor: visual.color.withOpacity(0.12),
              foregroundColor: visual.color,
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }


  Widget _tableHeader(String text, {required double width, bool alignEnd = false}) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _desktopTable(List<EmpresasResponseModel> empresas, ModuleVisual visual) {
    if (empresas.isEmpty) return _emptyState();

    const double minTableWidth = 1180;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: const BorderSide(color: AppColors.border)),
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
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 68,
                  columnSpacing: 12,
                  horizontalMargin: 12,
                  headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt),
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  dataTextStyle: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  columns: [
                    DataColumn(label: _tableHeader('Nombre comercial', width: 145)),
                    DataColumn(label: _tableHeader('Razón social', width: 150)),
                    DataColumn(label: _tableHeader('Tipo de identificación', width: 155)),
                    DataColumn(label: _tableHeader('Identificación', width: 105)),
                    DataColumn(label: _tableHeader('País / ciudad', width: 145)),
                    DataColumn(label: _tableHeader('Teléfono', width: 105)),
                    DataColumn(label: _tableHeader('Correo electrónico', width: 160)),
                    DataColumn(label: _tableHeader('Acciones', width: 120, alignEnd: true)),
                  ],
                  rows: empresas.map((empresa) {
                    return DataRow(
                      cells: [
                        DataCell(SizedBox(width: 145, child: Text(_text(empresa.empreNombreComercial), overflow: TextOverflow.ellipsis))),
                        DataCell(SizedBox(width: 150, child: Text(_text(empresa.emprRazonSocial), overflow: TextOverflow.ellipsis))),
                        DataCell(SizedBox(width: 155, child: Text(_tipoIdentificacion(empresa.tiidId), overflow: TextOverflow.ellipsis))),
                        DataCell(SizedBox(width: 105, child: Text(_text(empresa.emprIdentificacion), overflow: TextOverflow.ellipsis))),
                        DataCell(SizedBox(width: 145, child: Text(_paisCiudad(empresa), overflow: TextOverflow.ellipsis))),
                        DataCell(SizedBox(width: 105, child: Text(_text(empresa.emprTelefono), overflow: TextOverflow.ellipsis))),
                        DataCell(SizedBox(width: 160, child: Text(_text(empresa.emprCorreoElectronico), overflow: TextOverflow.ellipsis))),
                        DataCell(SizedBox(width: 120, child: _actions(empresa, visual))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _mobileCards(List<EmpresasResponseModel> empresas, ModuleVisual visual) {
    if (empresas.isEmpty) return _emptyState();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      child: Column(
        children: empresas.map((empresa) {
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.business_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_text(empresa.empreNombreComercial), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(_text(empresa.emprRazonSocial), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _mobileInfo('Tipo de identificación', _tipoIdentificacion(empresa.tiidId)),
                _mobileInfo('Identificación', _text(empresa.emprIdentificacion)),
                _mobileInfo('País / ciudad', _paisCiudad(empresa)),
                _mobileInfo('Teléfono', _text(empresa.emprTelefono)),
                _mobileInfo('Correo electrónico', _text(empresa.emprCorreoElectronico)),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: _actions(empresa, visual)),
              ],
            ),
          ),
        );
        }).toList(),
      ),
    );
  }

  Widget _mobileInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 135, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  Widget _actions(EmpresasResponseModel empresa, ModuleVisual visual) {
    final id = empresa.emprId;

    Widget buildAction({
      required String tooltip,
      required VoidCallback? onPressed,
      required IconData icon,
      required Color color,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: IconButton.filledTonal(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: color.withOpacity(0.12),
            foregroundColor: color,
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(34, 34),
            maximumSize: const Size(34, 34),
          ),
          icon: Icon(icon, size: 17),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildAction(
          tooltip: 'Visualizar',
          onPressed: id == null ? null : () => _safeGo('/empresas/$id'),
          icon: Icons.visibility_rounded,
          color: visual.color,
        ),
        buildAction(
          tooltip: 'Modificar',
          onPressed: id == null ? null : () => _safeGo('/empresas/$id/editar'),
          icon: Icons.edit_rounded,
          color: AppColors.warning,
        ),
        buildAction(
          tooltip: 'Eliminar',
          onPressed: id == null ? null : () => _confirmDelete(empresa),
          icon: Icons.delete_outline_rounded,
          color: AppColors.danger,
        ),
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

  Widget _emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 54, color: AppColors.textSecondary.withOpacity(0.7)),
            const SizedBox(height: 12),
            const Text('No hay empresas para mostrar', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Ajusta la búsqueda o registra una nueva empresa.', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
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
