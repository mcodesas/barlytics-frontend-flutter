import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../data/admin_support_repository.dart';

class ProductCatalogSyncPage extends ConsumerStatefulWidget {
  const ProductCatalogSyncPage({super.key});

  @override
  ConsumerState<ProductCatalogSyncPage> createState() => _ProductCatalogSyncPageState();
}

class _ProductCatalogSyncPageState extends ConsumerState<ProductCatalogSyncPage> {
  final _searchController = TextEditingController();
  final _reasonController = TextEditingController();
  final _money = NumberFormat.currency(locale: 'es_CO', symbol: r'$ ', decimalDigits: 0);

  bool _loading = true;
  bool _previewing = false;
  bool _executing = false;
  bool _includeImages = true;
  String? _error;
  String _mode = 'COPY_MISSING';
  int? _sourceCompanyId;
  int? _sourceBranchId;
  int? _targetCompanyId;
  final Set<int> _targetBranchIds = <int>{};
  final Set<int> _selectedProductIds = <int>{};
  List<Map<String, dynamic>> _companies = const [];
  List<Map<String, dynamic>> _branches = const [];
  List<Map<String, dynamic>> _rules = const [];
  Map<String, dynamic> _scope = const <String, dynamic>{};
  Map<String, dynamic>? _preview;
  List<Map<String, dynamic>> _history = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(adminSupportRepositoryProvider);
      final results = await Future.wait<Map<String, dynamic>>([
        repository.productCatalogSyncOptions(),
        repository.productCatalogSyncHistory(),
      ]);
      final options = results[0];
      final history = results[1];
      if (!mounted) return;
      final companies = _maps(options['companies']);
      final branches = _maps(options['branches']);
      final scope = _map(options['scope']);
      final crossCompanyAllowed = scope['crossCompanyAllowed'] == true;
      final lockedCompanyId = _int(scope['companyId']) ??
          (companies.length == 1 ? _int(companies.first['id']) : null);
      final preferredBranchId = _int(scope['preferredBranchId']);
      setState(() {
        _companies = companies;
        _branches = branches;
        _scope = scope;
        _rules = (options['rules'] as List? ?? const [])
            .map((value) => <String, dynamic>{'text': value.toString()})
            .toList(growable: false);
        _history = _maps(history['records']);
        if (!crossCompanyAllowed && lockedCompanyId != null) {
          _sourceCompanyId = lockedCompanyId;
          _targetCompanyId = lockedCompanyId;
          final allowedBranchIds = branches
              .map((item) => _int(item['id']))
              .whereType<int>()
              .toSet();
          _sourceBranchId = preferredBranchId != null && allowedBranchIds.contains(preferredBranchId)
              ? preferredBranchId
              : (allowedBranchIds.isEmpty ? null : allowedBranchIds.first);
          _targetBranchIds.removeWhere((id) => !allowedBranchIds.contains(id) || id == _sourceBranchId);
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _branchesOf(int? companyId) {
    if (companyId == null) return const [];
    return _branches.where((item) => _int(item['companyId']) == companyId).toList(growable: false);
  }

  bool get _crossCompanyAllowed => _scope['crossCompanyAllowed'] == true;
  bool get _companyLocked => _scope['companyLocked'] == true;
  String get _scopeLabel => _scope['roleLabel']?.toString() ?? 'Usuario autorizado';
  String get _scopeDescription => _scope['description']?.toString() ??
      'La operación está limitada a las empresas y sucursales autorizadas.';
  String get _lockedCompanyName => _scope['companyName']?.toString() ??
      (_companies.isNotEmpty ? (_companies.first['name']?.toString() ?? 'Empresa asignada') : 'Empresa asignada');

  Future<void> _previewCatalog() async {
    if (_sourceCompanyId == null ||
        _sourceBranchId == null ||
        _targetCompanyId == null ||
        _targetBranchIds.isEmpty) {
      _snack(_crossCompanyAllowed
          ? 'Selecciona empresa y sucursal origen, empresa destino y al menos una sucursal destino.'
          : 'Selecciona una sucursal origen y al menos una sucursal destino diferente.');
      return;
    }
    setState(() {
      _previewing = true;
      _error = null;
      _preview = null;
      _selectedProductIds.clear();
    });
    try {
      final data = await ref.read(adminSupportRepositoryProvider).previewProductCatalogSync(
            sourceCompanyId: _sourceCompanyId!,
            sourceBranchId: _sourceBranchId!,
            targetCompanyId: _targetCompanyId!,
            targetBranchIds: _targetBranchIds.toList(growable: false),
            mode: _mode,
            search: _searchController.text,
            includeImages: _includeImages,
          );
      final products = _maps(data['products']);
      if (!mounted) return;
      setState(() {
        _preview = data;
        for (final product in products) {
          if (product['eligible'] == true) {
            final id = _int(product['prodId']);
            if (id != null) _selectedProductIds.add(id);
          }
        }
        _previewing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _previewing = false;
      });
    }
  }

  Future<void> _execute() async {
    if (_selectedProductIds.isEmpty) {
      _snack('Selecciona al menos un producto con precio de compra.');
      return;
    }
    _reasonController.clear();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = ref.read(selectedAppPaletteProvider);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: palette.primary.withOpacity(.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.sync_alt_rounded, color: palette.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Confirmar operación', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
                            Text('${_selectedProductIds.length} productos · ${_targetBranchIds.length} sucursales destino', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Notice(
                    icon: Icons.inventory_2_outlined,
                    text: 'No se crearán existencias, inventarios ni movimientos.',
                    color: palette.success,
                    palette: palette,
                  ),
                  const SizedBox(height: 8),
                  _Notice(
                    icon: Icons.sell_outlined,
                    text: 'No se copiará el precio de venta. Los precios de venta existentes se conservarán.',
                    color: palette.info,
                    palette: palette,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _reasonController,
                    minLines: 2,
                    maxLines: 4,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Motivo del soporte',
                      hintText: 'Ej. Apertura de nueva empresa con catálogo base',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(sheetContext, false), child: const Text('Cancelar')),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          if (_reasonController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Indica el motivo de la operación.')));
                            return;
                          }
                          Navigator.pop(sheetContext, true);
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Ejecutar'),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _executing = true);
    try {
      final result = await ref.read(adminSupportRepositoryProvider).executeProductCatalogSync(
            sourceCompanyId: _sourceCompanyId!,
            sourceBranchId: _sourceBranchId!,
            targetCompanyId: _targetCompanyId!,
            targetBranchIds: _targetBranchIds.toList(growable: false),
            mode: _mode,
            productIds: _selectedProductIds.toList(growable: false),
            reason: _reasonController.text,
            includeImages: _includeImages,
          );
      if (!mounted) return;
      setState(() => _executing = false);
      await _showResult(result);
      await _loadHistory();
      await _previewCatalog();
    } catch (error) {
      if (!mounted) return;
      setState(() => _executing = false);
      _snack(_message(error), error: true);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final data = await ref.read(adminSupportRepositoryProvider).productCatalogSyncHistory();
      if (!mounted) return;
      setState(() => _history = _maps(data['records']));
    } catch (_) {}
  }

  Future<void> _showResult(Map<String, dynamic> result) async {
    final palette = ref.read(selectedAppPaletteProvider);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(children: [Icon(Icons.check_circle_rounded), SizedBox(width: 9), Text('Sincronización completada')]),
        content: SizedBox(
          width: 520,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ResultMetric(label: 'Productos creados', value: '${result['productsCreated'] ?? 0}', color: palette.success),
              _ResultMetric(label: 'Productos actualizados', value: '${result['productsUpdated'] ?? 0}', color: palette.info),
              _ResultMetric(label: 'Costos creados', value: '${result['purchasePricesCreated'] ?? 0}', color: palette.primary),
              _ResultMetric(label: 'Costos actualizados', value: '${result['purchasePricesUpdated'] ?? 0}', color: palette.secondary),
              _ResultMetric(label: 'Omitidos', value: '${result['skipped'] ?? 0}', color: palette.warning),
              _ResultMetric(label: 'Inventarios creados', value: '${result['stockCreated'] ?? 0}', color: palette.textSecondary),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cerrar'))],
      ),
    );
  }

  Future<void> _showHistoryDetail(int runId) async {
    final palette = ref.read(selectedAppPaletteProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FutureBuilder<Map<String, dynamic>>(
        future: ref.read(adminSupportRepositoryProvider).productCatalogSyncHistoryDetail(runId),
        builder: (context, snapshot) {
          return SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(12),
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * .88),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: palette.cardBorder),
              ),
              child: snapshot.connectionState != ConnectionState.done
                  ? const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()))
                  : snapshot.hasError
                      ? SizedBox(height: 260, child: Center(child: Text(_message(snapshot.error!))))
                      : _HistoryDetail(data: snapshot.data ?? const {}, money: _money, palette: palette),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _Hero(
              palette: palette,
              onRefresh: _load,
              crossCompanyAllowed: _crossCompanyAllowed,
              scopeLabel: _scopeLabel,
            ),
            const SizedBox(height: 12),
            _ScopeBanner(
              palette: palette,
              label: _scopeLabel,
              description: _scopeDescription,
              crossCompanyAllowed: _crossCompanyAllowed,
            ),
            const SizedBox(height: 14),
            if (_error != null) ...[
              _ErrorBanner(message: _error!, palette: palette),
              const SizedBox(height: 12),
            ],
            _RulesPanel(rules: _rules, palette: palette),
            const SizedBox(height: 14),
            _buildConfiguration(palette),
            const SizedBox(height: 14),
            if (_previewing)
              _LoadingPanel(palette: palette)
            else if (_preview != null)
              _buildPreview(palette),
            const SizedBox(height: 14),
            _buildHistory(palette),
          ],
        ),
      ),
    );
  }

  Widget _buildConfiguration(AppPalette palette) {
    final sourceBranches = _branchesOf(_sourceCompanyId);
    final targetBranches = _branchesOf(_targetCompanyId)
        .where((item) => _int(item['id']) != _sourceBranchId)
        .toList(growable: false);
    return _Panel(
      palette: palette,
      title: _crossCompanyAllowed ? 'Configurar sincronización entre empresas' : 'Configurar sincronización entre sucursales',
      subtitle: _crossCompanyAllowed
          ? 'Selecciona de dónde tomar el catálogo y en cuáles sucursales de otra empresa debe quedar disponible.'
          : 'Selecciona una sucursal origen y una o varias sucursales destino de la misma empresa.',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_companyLocked) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.primary.withOpacity(.055),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.primary.withOpacity(.14)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: palette.primary, size: 19),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Empresa autorizada', style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                        Text(_lockedCompanyName, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  Text('No se puede cambiar', style: TextStyle(color: palette.primary, fontSize: 11, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 780;
              final source = _LocationSelector(
                title: 'Origen',
                color: palette.primary,
                companies: _companies,
                branches: sourceBranches,
                companyId: _sourceCompanyId,
                branchId: _sourceBranchId,
                excludedCompanyId: _crossCompanyAllowed ? _targetCompanyId : null,
                companyLocked: _companyLocked,
                onCompanyChanged: (value) => setState(() {
                  _sourceCompanyId = value;
                  _sourceBranchId = null;
                  _preview = null;
                }),
                onBranchChanged: (value) => setState(() {
                  _sourceBranchId = value;
                  if (value != null) _targetBranchIds.remove(value);
                  _preview = null;
                }),
              );
              final target = _TargetSelector(
                palette: palette,
                companies: _companies,
                branches: targetBranches,
                companyId: _targetCompanyId,
                selectedBranchIds: _targetBranchIds,
                excludedCompanyId: _crossCompanyAllowed ? _sourceCompanyId : null,
                companyLocked: _companyLocked,
                onCompanyChanged: (value) => setState(() {
                  _targetCompanyId = value;
                  _targetBranchIds.clear();
                  _preview = null;
                }),
                onToggleBranch: (id, selected) => setState(() {
                  selected ? _targetBranchIds.add(id) : _targetBranchIds.remove(id);
                  _preview = null;
                }),
              );
              if (wide) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: source), const SizedBox(width: 12), Expanded(child: target)]);
              }
              return Column(children: [source, const SizedBox(height: 12), target]);
            },
          ),
          const SizedBox(height: 14),
          Text('Modo de operación', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 650;
              final cards = [
                _ModeCard(
                  selected: _mode == 'COPY_MISSING',
                  title: 'Copiar solo faltantes',
                  description: 'Crea productos que no existen. No modifica los que ya están en el destino.',
                  icon: Icons.content_copy_rounded,
                  color: palette.info,
                  palette: palette,
                  onTap: () => setState(() {
                    _mode = 'COPY_MISSING';
                    _preview = null;
                  }),
                ),
                _ModeCard(
                  selected: _mode == 'SYNCHRONIZE',
                  title: 'Sincronizar existentes',
                  description: 'Crea faltantes y actualiza producto y costo, preservando siempre el precio de venta.',
                  icon: Icons.sync_rounded,
                  color: palette.secondary,
                  palette: palette,
                  onTap: () => setState(() {
                    _mode = 'SYNCHRONIZE';
                    _preview = null;
                  }),
                ),
              ];
              if (wide) return Row(children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1])]);
              return Column(children: [cards[0], const SizedBox(height: 10), cards[1]]);
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final search = TextField(
                controller: _searchController,
                onSubmitted: (_) => _previewCatalog(),
                decoration: const InputDecoration(
                  hintText: 'Buscar producto o marca en el origen',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              );
              final imageSwitch = SwitchListTile.adaptive(
                value: _includeImages,
                onChanged: (value) => setState(() {
                  _includeImages = value;
                  _preview = null;
                }),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                dense: true,
                title: const Text('Copiar imágenes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                subtitle: const Text('Puede aumentar el tiempo de la operación.', style: TextStyle(fontSize: 11)),
              );
              if (constraints.maxWidth >= 760) {
                return Row(children: [Expanded(child: search), const SizedBox(width: 10), SizedBox(width: 220, child: imageSwitch), const SizedBox(width: 10), _PreviewButton(loading: _previewing, onPressed: _previewCatalog)]);
              }
              return Column(children: [search, const SizedBox(height: 8), imageSwitch, const SizedBox(height: 8), Align(alignment: Alignment.centerRight, child: _PreviewButton(loading: _previewing, onPressed: _previewCatalog))]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(AppPalette palette) {
    final preview = _preview ?? const <String, dynamic>{};
    final summary = _map(preview['summary']);
    final products = _maps(preview['products']);
    final eligibleIds = products.where((item) => item['eligible'] == true).map((item) => _int(item['prodId'])).whereType<int>().toSet();
    final allSelected = eligibleIds.isNotEmpty && _selectedProductIds.containsAll(eligibleIds);

    return _Panel(
      palette: palette,
      title: 'Vista previa',
      subtitle: '${preview['sourceCompany'] ?? ''} · ${preview['sourceBranch'] ?? ''} → ${preview['targetCompany'] ?? ''}',
      icon: Icons.fact_check_rounded,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: allSelected,
            tristate: _selectedProductIds.isNotEmpty && !allSelected,
            onChanged: (_) => setState(() {
              if (allSelected) {
                _selectedProductIds.removeAll(eligibleIds);
              } else {
                _selectedProductIds.addAll(eligibleIds);
              }
            }),
          ),
          Text('Seleccionar válidos', style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _SummaryChip(label: 'Productos origen', value: '${summary['sourceProducts'] ?? 0}', icon: Icons.local_bar_rounded, color: palette.primary),
              _SummaryChip(label: 'Listos', value: '${summary['eligibleProducts'] ?? 0}', icon: Icons.check_circle_outline_rounded, color: palette.success),
              _SummaryChip(label: 'Crear', value: '${summary['createOperations'] ?? 0}', icon: Icons.add_circle_outline_rounded, color: palette.info),
              _SummaryChip(label: 'Actualizar', value: '${summary['updateOperations'] ?? 0}', icon: Icons.sync_rounded, color: palette.secondary),
              _SummaryChip(label: 'Omitir', value: '${summary['skipOperations'] ?? 0}', icon: Icons.skip_next_rounded, color: palette.warning),
              _SummaryChip(label: 'Sin costo', value: '${summary['withoutPurchasePrice'] ?? 0}', icon: Icons.money_off_rounded, color: palette.danger),
            ],
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: [Icon(Icons.search_off_rounded, size: 42, color: palette.textSecondary), const SizedBox(height: 8), Text('No se encontraron productos para la selección actual.', style: TextStyle(color: palette.textSecondary))]),
            )
          else
            for (final product in products)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _ProductPreviewCard(
                  product: product,
                  selected: _selectedProductIds.contains(_int(product['prodId'])),
                  money: _money,
                  palette: palette,
                  onChanged: product['eligible'] == true
                      ? (selected) {
                          final id = _int(product['prodId']);
                          if (id == null) return;
                          setState(() => selected ? _selectedProductIds.add(id) : _selectedProductIds.remove(id));
                        }
                      : null,
                ),
              ),
          if (products.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: palette.primary.withOpacity(.055), borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.cardBorder)),
              child: Row(
                children: [
                  Expanded(child: Text('${_selectedProductIds.length} productos seleccionados para ${_targetBranchIds.length} sucursales.', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800))),
                  FilledButton.icon(
                    onPressed: _executing ? null : _execute,
                    icon: _executing ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync_alt_rounded, size: 18),
                    label: Text(_executing ? 'Procesando...' : _mode == 'SYNCHRONIZE' ? 'Sincronizar' : 'Copiar catálogo'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistory(AppPalette palette) {
    return _Panel(
      palette: palette,
      title: 'Historial de sincronizaciones',
      subtitle: _crossCompanyAllowed
          ? 'Trazabilidad de copias realizadas entre empresas y sucursales.'
          : 'Trazabilidad limitada a las sucursales autorizadas de tu empresa.',
      icon: Icons.history_rounded,
      trailing: IconButton(onPressed: _loadHistory, tooltip: 'Actualizar historial', icon: const Icon(Icons.refresh_rounded)),
      child: _history.isEmpty
          ? Padding(padding: const EdgeInsets.all(24), child: Text('Todavía no se han ejecutado sincronizaciones.', style: TextStyle(color: palette.textSecondary)))
          : Column(
              children: [
                for (final item in _history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HistoryTile(
                      item: item,
                      palette: palette,
                      onTap: () {
                        final id = _int(item['id']);
                        if (id != null) _showHistoryDetail(id);
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? Theme.of(context).colorScheme.error : null));
  }

  static List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
  static Map<String, dynamic> _map(Object? value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static int? _int(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  static String _message(Object error) => error.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
}

class _ScopeBanner extends StatelessWidget {
  const _ScopeBanner({
    required this.palette,
    required this.label,
    required this.description,
    required this.crossCompanyAllowed,
  });

  final AppPalette palette;
  final String label;
  final String description;
  final bool crossCompanyAllowed;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: palette.info.withOpacity(.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.info.withOpacity(.16)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: palette.info.withOpacity(.11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                crossCompanyAllowed ? Icons.public_rounded : Icons.account_tree_rounded,
                color: palette.info,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(description, style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.palette,
    required this.onRefresh,
    required this.crossCompanyAllowed,
    required this.scopeLabel,
  });

  final AppPalette palette;
  final VoidCallback onRefresh;
  final bool crossCompanyAllowed;
  final String scopeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: palette.panelDecoration(baseRadius: 26, tint: palette.primary),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: palette.primary.withOpacity(.10), borderRadius: BorderRadius.circular(999)),
                child: Text(scopeLabel.toUpperCase(), style: TextStyle(color: palette.primary, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: .4)),
              ),
              const SizedBox(height: 11),
              Text('Copiar y sincronizar productos', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(crossCompanyAllowed
                  ? 'Replica la información comercial y el precio de compra de una empresa a otra. El destino queda sin stock y sin precio de venta hasta que el cliente los configure.'
                  : 'Replica productos y costos de compra entre sucursales autorizadas de la misma empresa, sin mover existencias ni copiar precios de venta.', style: TextStyle(color: palette.textSecondary, height: 1.42)),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroTag(icon: Icons.inventory_2_outlined, label: 'Sin stock', color: palette.success),
                  _HeroTag(icon: Icons.sell_outlined, label: 'Sin precio de venta', color: palette.info),
                  _HeroTag(icon: Icons.price_check_rounded, label: 'Con costo de compra', color: palette.secondary),
                  _HeroTag(icon: Icons.history_rounded, label: 'Con auditoría', color: palette.warning),
                ],
              ),
            ],
          );
          final icon = Container(width: 92, height: 92, decoration: BoxDecoration(color: palette.primary.withOpacity(.10), borderRadius: BorderRadius.circular(28)), child: Icon(Icons.sync_alt_rounded, color: palette.primary, size: 50));
          if (constraints.maxWidth < 720) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [icon, const SizedBox(height: 14), content]);
          return Row(children: [Expanded(child: content), const SizedBox(width: 18), icon, const SizedBox(width: 8), IconButton(onPressed: onRefresh, tooltip: 'Actualizar', icon: const Icon(Icons.refresh_rounded))]);
        },
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 15), const SizedBox(width: 5), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11))]));
}

class _RulesPanel extends StatelessWidget {
  const _RulesPanel({required this.rules, required this.palette});
  final List<Map<String, dynamic>> rules;
  final AppPalette palette;
  @override
  Widget build(BuildContext context) {
    final values = rules.isEmpty
        ? const [
            {'text': 'Nunca crea inventario ni movimientos.'},
            {'text': 'Nunca copia ni reemplaza precios de venta.'},
            {'text': 'Solo procesa productos con precio de compra.'},
          ]
        : rules;
    return _Panel(
      palette: palette,
      title: 'Reglas de seguridad',
      subtitle: 'La operación está limitada para no alterar existencias ni tarifas de venta.',
      icon: Icons.verified_user_rounded,
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [for (final rule in values) _Notice(icon: Icons.check_rounded, text: rule['text']?.toString() ?? '', color: palette.success, palette: palette)],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.palette, required this.title, required this.subtitle, required this.icon, required this.child, this.trailing});
  final AppPalette palette;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: palette.panelDecoration(baseRadius: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: palette.primary.withOpacity(.09), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: palette.primary, size: 21)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)), Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 11.5))])), if (trailing != null) trailing!]),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.color, required this.palette});
  final IconData icon;
  final String text;
  final Color color;
  final AppPalette palette;
  @override
  Widget build(BuildContext context) => Container(constraints: const BoxConstraints(minWidth: 230), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(.07), borderRadius: BorderRadius.circular(13), border: Border.all(color: color.withOpacity(.15))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 17), const SizedBox(width: 7), Flexible(child: Text(text, style: TextStyle(color: palette.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w700)))]));
}

class _LocationSelector extends StatelessWidget {
  const _LocationSelector({required this.title, required this.color, required this.companies, required this.branches, required this.companyId, required this.branchId, required this.onCompanyChanged, required this.onBranchChanged, required this.companyLocked, this.excludedCompanyId});
  final String title;
  final Color color;
  final List<Map<String, dynamic>> companies;
  final List<Map<String, dynamic>> branches;
  final int? companyId;
  final int? branchId;
  final int? excludedCompanyId;
  final bool companyLocked;
  final ValueChanged<int?> onCompanyChanged;
  final ValueChanged<int?> onBranchChanged;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: color.withOpacity(.045), borderRadius: BorderRadius.circular(17), border: Border.all(color: color.withOpacity(.14))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.upload_rounded, color: color, size: 19), const SizedBox(width: 7), Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 10),
          if (!companyLocked)
            DropdownButtonFormField<int>(
              value: companyId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Empresa', prefixIcon: Icon(Icons.business_rounded), isDense: true),
              items: [for (final company in companies) if (_ProductCatalogSyncPageState._int(company['id']) != excludedCompanyId) DropdownMenuItem(value: _ProductCatalogSyncPageState._int(company['id']), child: Text(company['name']?.toString() ?? 'Empresa'))],
              onChanged: onCompanyChanged,
            )
          else
            _LockedCompanyCompact(name: companies.isEmpty ? 'Empresa asignada' : (companies.first['name']?.toString() ?? 'Empresa asignada'), color: color),
          const SizedBox(height: 9),
          DropdownButtonFormField<int>(
            value: branches.any((item) => _ProductCatalogSyncPageState._int(item['id']) == branchId) ? branchId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Sucursal origen', prefixIcon: Icon(Icons.store_rounded), isDense: true),
            items: [for (final branch in branches) DropdownMenuItem(value: _ProductCatalogSyncPageState._int(branch['id']), child: Text('${branch['name'] ?? 'Sucursal'} · ${branch['productCount'] ?? 0} productos'))],
            onChanged: companyId == null ? null : onBranchChanged,
          ),
        ]),
      );
}

class _TargetSelector extends StatelessWidget {
  const _TargetSelector({required this.palette, required this.companies, required this.branches, required this.companyId, required this.selectedBranchIds, required this.onCompanyChanged, required this.onToggleBranch, required this.companyLocked, this.excludedCompanyId});
  final AppPalette palette;
  final List<Map<String, dynamic>> companies;
  final List<Map<String, dynamic>> branches;
  final int? companyId;
  final Set<int> selectedBranchIds;
  final int? excludedCompanyId;
  final bool companyLocked;
  final ValueChanged<int?> onCompanyChanged;
  final void Function(int id, bool selected) onToggleBranch;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: palette.secondary.withOpacity(.045), borderRadius: BorderRadius.circular(17), border: Border.all(color: palette.secondary.withOpacity(.14))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.download_rounded, color: palette.secondary, size: 19), const SizedBox(width: 7), Text('Destino', style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 10),
          if (!companyLocked)
            DropdownButtonFormField<int>(
              value: companyId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Empresa destino', prefixIcon: Icon(Icons.business_rounded), isDense: true),
              items: [for (final company in companies) if (_ProductCatalogSyncPageState._int(company['id']) != excludedCompanyId) DropdownMenuItem(value: _ProductCatalogSyncPageState._int(company['id']), child: Text(company['name']?.toString() ?? 'Empresa'))],
              onChanged: onCompanyChanged,
            )
          else
            _LockedCompanyCompact(name: companies.isEmpty ? 'Empresa asignada' : (companies.first['name']?.toString() ?? 'Empresa asignada'), color: palette.secondary),
          const SizedBox(height: 10),
          Text('Sucursales destino', style: TextStyle(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          if (companyId == null)
            Text('Selecciona primero la empresa destino.', style: TextStyle(color: palette.textSecondary, fontSize: 11.5))
          else if (branches.isEmpty)
            Text(companyLocked ? 'No hay otra sucursal autorizada disponible.' : 'La empresa no tiene sucursales disponibles.', style: TextStyle(color: palette.danger, fontSize: 11.5))
          else
            Wrap(spacing: 7, runSpacing: 7, children: [for (final branch in branches) FilterChip(selected: selectedBranchIds.contains(_ProductCatalogSyncPageState._int(branch['id'])), avatar: const Icon(Icons.store_rounded, size: 16), label: Text(branch['name']?.toString() ?? 'Sucursal'), onSelected: (selected) { final id = _ProductCatalogSyncPageState._int(branch['id']); if (id != null) onToggleBranch(id, selected); })]),
        ]),
      );
}

class _LockedCompanyCompact extends StatelessWidget {
  const _LockedCompanyCompact({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(.055),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withOpacity(.13)),
        ),
        child: Row(
          children: [
            Icon(Icons.business_rounded, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12))),
            Icon(Icons.lock_rounded, color: color, size: 15),
          ],
        ),
      );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.selected, required this.title, required this.description, required this.icon, required this.color, required this.palette, required this.onTap});
  final bool selected;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final AppPalette palette;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: selected ? color.withOpacity(.10) : palette.background.withOpacity(.32), borderRadius: BorderRadius.circular(17), border: Border.all(color: selected ? color.withOpacity(.55) : palette.cardBorder, width: selected ? 1.5 : 1)),
          child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)), const SizedBox(height: 2), Text(description, style: TextStyle(color: palette.textSecondary, fontSize: 10.8, height: 1.3))])), Radio<bool>(value: true, groupValue: selected, onChanged: (_) => onTap())]),
        ),
      );
}

class _PreviewButton extends StatelessWidget {
  const _PreviewButton({required this.loading, required this.onPressed});
  final bool loading;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => FilledButton.icon(onPressed: loading ? null : onPressed, icon: loading ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.visibility_rounded, size: 18), label: Text(loading ? 'Consultando...' : 'Generar vista previa'), style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)));
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.palette});
  final AppPalette palette;
  @override
  Widget build(BuildContext context) => _Panel(palette: palette, title: 'Preparando vista previa', subtitle: 'Comparando productos y costos en las sucursales destino.', icon: Icons.hourglass_top_rounded, child: const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())));
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(14)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 17), const SizedBox(width: 6), Text('$label: ', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)), Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900))]));
}

class _ProductPreviewCard extends StatelessWidget {
  const _ProductPreviewCard({required this.product, required this.selected, required this.money, required this.palette, required this.onChanged});
  final Map<String, dynamic> product;
  final bool selected;
  final NumberFormat money;
  final AppPalette palette;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final targets = _ProductCatalogSyncPageState._maps(product['targets']);
    final price = product['purchasePrice'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: selected ? palette.primary.withOpacity(.055) : palette.background.withOpacity(.28), borderRadius: BorderRadius.circular(17), border: Border.all(color: selected ? palette.primary.withOpacity(.28) : palette.cardBorder)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Checkbox(value: selected, onChanged: onChanged == null ? null : (value) => onChanged!(value == true)),
        const SizedBox(width: 3),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(product['name']?.toString() ?? 'Producto', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: price == null ? palette.danger.withOpacity(.09) : palette.success.withOpacity(.09), borderRadius: BorderRadius.circular(999)), child: Text(price == null ? 'Sin costo' : money.format(price), style: TextStyle(color: price == null ? palette.danger : palette.success, fontSize: 11, fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 3),
          Text('${product['brand'] ?? 'Sin marca'} · ${product['type'] ?? 'Sin tipo'}${product['purchasePresentation'] == null ? '' : ' · ${product['purchasePresentation']}'}', style: TextStyle(color: palette.textSecondary, fontSize: 11)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final target in targets) _ActionTag(target: target, palette: palette)]),
        ])),
      ]),
    );
  }
}

class _ActionTag extends StatelessWidget {
  const _ActionTag({required this.target, required this.palette});

  final Map<String, dynamic> target;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final action = target['action']?.toString() ?? '';
    final color = switch (action) {
      'CREATE' => palette.success,
      'UPDATE' => palette.info,
      'NO_PURCHASE_PRICE' => palette.danger,
      'ID_CONFLICT' => palette.danger,
      _ => palette.warning,
    };
    final icon = action == 'CREATE'
        ? Icons.add_rounded
        : action == 'UPDATE'
            ? Icons.sync_rounded
            : action == 'NO_PURCHASE_PRICE'
                ? Icons.money_off_rounded
                : action == 'ID_CONFLICT'
                    ? Icons.warning_amber_rounded
                    : Icons.skip_next_rounded;
    return Tooltip(
      message: target['message']?.toString() ?? target['label']?.toString() ?? action,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              '${target['branchName'] ?? 'Sucursal'} · ${target['label'] ?? action}',
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.item,
    required this.palette,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final synchronize = item['mode']?.toString() == 'SYNCHRONIZE';
    final mode = synchronize ? 'Sincronización' : 'Copia';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.background.withOpacity(.28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.primary.withOpacity(.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  synchronize ? Icons.sync_rounded : Icons.content_copy_rounded,
                  color: palette.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$mode · ${item['sourceCompany'] ?? ''} → ${item['targetCompany'] ?? ''}',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item['selectedProducts'] ?? 0} productos · ${item['targetBranches'] ?? 0} sucursales · ${item['actor'] ?? ''}',
                      style: TextStyle(color: palette.textSecondary, fontSize: 10.8),
                    ),
                    Text(
                      '${item['productsCreated'] ?? 0} creados · ${item['productsUpdated'] ?? 0} actualizados · ${item['skipped'] ?? 0} omitidos',
                      style: TextStyle(color: palette.textSecondary, fontSize: 10.8),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryDetail extends StatelessWidget {
  const _HistoryDetail({
    required this.data,
    required this.money,
    required this.palette,
  });

  final Map<String, dynamic> data;
  final NumberFormat money;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final run = _ProductCatalogSyncPageState._map(data['run']);
    final items = _ProductCatalogSyncPageState._maps(data['items']);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle de sincronización #${run['pcsr_id'] ?? ''}',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '${run['source_company'] ?? ''} · ${run['source_branch'] ?? ''} → ${run['target_company'] ?? ''}',
                      style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.primary.withOpacity(.05),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  'Motivo: ${run['reason'] ?? ''}',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              for (final item in items)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: palette.background.withOpacity(.30),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item['status'] == 'SUCCESS'
                            ? Icons.check_circle_rounded
                            : Icons.info_rounded,
                        color: item['status'] == 'SUCCESS'
                            ? palette.success
                            : palette.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['productName'] ?? 'Producto'} · ${item['targetBranch'] ?? 'Sucursal'}',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              item['message']?.toString() ?? '',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 10.8,
                              ),
                            ),
                            if (item['purchasePrice'] != null)
                              Text(
                                'Costo: ${money.format(item['purchasePrice'])}',
                                style: TextStyle(
                                  color: palette.success,
                                  fontSize: 10.8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: 155, padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20)), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10.5))]));
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.palette});
  final String message;
  final AppPalette palette;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: palette.danger.withOpacity(.08), borderRadius: BorderRadius.circular(15), border: Border.all(color: palette.danger.withOpacity(.18))), child: Row(children: [Icon(Icons.error_outline_rounded, color: palette.danger), const SizedBox(width: 9), Expanded(child: Text(message, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700)))]));
}
