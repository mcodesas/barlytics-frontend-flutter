import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../data/admin_support_repository.dart';

class AdminDataExplorerPage extends ConsumerStatefulWidget {
  const AdminDataExplorerPage({super.key, this.initialTable});

  final String? initialTable;

  @override
  ConsumerState<AdminDataExplorerPage> createState() => _AdminDataExplorerPageState();
}

class _AdminDataExplorerPageState extends ConsumerState<AdminDataExplorerPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _tables = const [];
  Map<String, dynamic>? _data;
  String? _table;
  int _page = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  @override
  void didUpdateWidget(covariant AdminDataExplorerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final requested = widget.initialTable?.trim().toLowerCase();
    final previous = oldWidget.initialTable?.trim().toLowerCase();
    if (requested == null || requested.isEmpty || requested == previous) return;
    if (!_tables.any((item) => item['table']?.toString() == requested)) return;
    setState(() {
      _table = requested;
      _data = null;
      _page = 0;
      _searchController.clear();
    });
    _loadRecords(resetPage: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTables() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tables = await ref.read(adminSupportRepositoryProvider).tables();
      var selected = widget.initialTable?.toLowerCase();
      if (selected == null || !tables.any((item) => item['table'] == selected)) {
        selected = tables.isEmpty ? null : tables.first['table']?.toString();
      }
      if (!mounted) return;
      setState(() {
        _tables = tables;
        _table = selected;
      });
      if (selected != null) await _loadRecords(resetPage: true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRecords({bool resetPage = false}) async {
    if (_table == null) return;
    if (resetPage) _page = 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(adminSupportRepositoryProvider).records(
            table: _table!,
            page: _page,
            size: 25,
            search: _searchController.text,
          );
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _loadRecords(resetPage: true));
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final records = _maps(_data?['records']);
    final columns = _maps(_data?['columns']);
    final primaryKeys = (_data?['primaryKeys'] as List? ?? const <Object?>[]).map((e) => e.toString()).toList();
    final total = _asInt(_data?['total']);
    final totalPages = _asInt(_data?['totalPages']);
    final visibleColumns = _visibleColumns(columns);
    final canCreate = _data?['creatable'] == true;
    final functionalRoute = _data?['functionalRoute']?.toString();
    final creationBlockedReason = _data?['creationBlockedReason']?.toString();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _ExplorerHeader(
            palette: palette,
            tables: _tables,
            selectedTable: _table,
            searchController: _searchController,
            total: total,
            onTableChanged: (value) {
              setState(() {
                _table = value;
                _data = null;
                _searchController.clear();
              });
              _loadRecords(resetPage: true);
            },
            onSearch: _onSearch,
            onRefresh: () => _loadRecords(),
            canCreate: canCreate,
            onCreate: canCreate ? () => _openCreate(columns, primaryKeys) : null,
            functionalRoute: functionalRoute,
            creationBlockedReason: creationBlockedReason,
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _ErrorBox(error: _error!, onRetry: () => _loadRecords(), palette: palette),
            ),
          Expanded(
            child: records.isEmpty && !_loading
                ? _EmptyExplorer(palette: palette)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 760) {
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: records.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _RecordCard(
                            record: records[index],
                            columns: visibleColumns,
                            primaryKeys: primaryKeys,
                            palette: palette,
                            onTap: () => _openRecord(records[index], columns, primaryKeys),
                          ),
                        );
                      }
                      return Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth - 32),
                            child: DataTable(
                              showCheckboxColumn: false,
                              headingRowHeight: 44,
                              dataRowMinHeight: 46,
                              dataRowMaxHeight: 56,
                              columns: [
                                for (final column in visibleColumns)
                                  DataColumn(label: Text(column['label']?.toString() ?? column['name'].toString())),
                                const DataColumn(label: Text('Acción')),
                              ],
                              rows: [
                                for (final record in records)
                                  DataRow(
                                    onSelectChanged: (_) => _openRecord(record, columns, primaryKeys),
                                    cells: [
                                      for (final column in visibleColumns)
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 210),
                                            child: Text(
                                              _display(record[column['name']?.toString()]),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      DataCell(
                                        IconButton(
                                          tooltip: 'Consultar y modificar',
                                          onPressed: () => _openRecord(record, columns, primaryKeys),
                                          icon: const Icon(Icons.edit_note_rounded),
                                        ),
                                      ),
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
          _PaginationBar(
            palette: palette,
            page: _page,
            totalPages: totalPages,
            total: total,
            onPrevious: _page <= 0
                ? null
                : () {
                    setState(() => _page--);
                    _loadRecords();
                  },
            onNext: totalPages <= 0 || _page + 1 >= totalPages
                ? null
                : () {
                    setState(() => _page++);
                    _loadRecords();
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _openCreate(
    List<Map<String, dynamic>> columns,
    List<String> primaryKeys,
  ) async {
    if (_table == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecordEditorSheet(
        table: _table!,
        title: _data?['title']?.toString() ?? _table!,
        record: const <String, dynamic>{},
        columns: columns,
        primaryKeys: primaryKeys,
        creating: true,
      ),
    );
    if (changed == true) await _loadRecords(resetPage: true);
  }

  Future<void> _openRecord(
    Map<String, dynamic> record,
    List<Map<String, dynamic>> columns,
    List<String> primaryKeys,
  ) async {
    if (_table == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecordEditorSheet(
        table: _table!,
        title: _data?['title']?.toString() ?? _table!,
        record: record,
        columns: columns,
        primaryKeys: primaryKeys,
        creating: false,
      ),
    );
    if (changed == true) await _loadRecords();
  }
}

class _ExplorerHeader extends StatelessWidget {
  const _ExplorerHeader({
    required this.palette,
    required this.tables,
    required this.selectedTable,
    required this.searchController,
    required this.total,
    required this.onTableChanged,
    required this.onSearch,
    required this.onRefresh,
    required this.canCreate,
    required this.onCreate,
    required this.functionalRoute,
    required this.creationBlockedReason,
  });

  final AppPalette palette;
  final List<Map<String, dynamic>> tables;
  final String? selectedTable;
  final TextEditingController searchController;
  final int total;
  final ValueChanged<String?> onTableChanged;
  final ValueChanged<String> onSearch;
  final VoidCallback onRefresh;
  final bool canCreate;
  final VoidCallback? onCreate;
  final String? functionalRoute;
  final String? creationBlockedReason;

  @override
  Widget build(BuildContext context) {
    final route = functionalRoute?.trim();
    final hasFunctionalRoute = route != null && route.isNotEmpty && !route.startsWith('/explorador_datos');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: palette.panelDecoration(baseRadius: 23, tint: palette.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: palette.primary.withOpacity(.11), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.storage_rounded, color: palette.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Explorador de datos', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(
                      'Consulta, crea y corrige registros con auditoría. Usa primero la vista funcional cuando exista.',
                      style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: onRefresh, tooltip: 'Actualizar', icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderChip(icon: Icons.table_rows_rounded, label: '$total registros', palette: palette),
              _HeaderChip(
                icon: canCreate ? Icons.add_circle_outline_rounded : Icons.lock_outline_rounded,
                label: canCreate ? 'Creación habilitada' : 'Solo consulta y edición',
                palette: palette,
              ),
              if (hasFunctionalRoute)
                OutlinedButton.icon(
                  onPressed: () => context.go(route!),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const Text('Abrir vista funcional'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12)),
                ),
              if (canCreate)
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nuevo registro'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 13)),
                ),
            ],
          ),
          if (!canCreate && creationBlockedReason != null && creationBlockedReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(.07),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.orange.withOpacity(.20)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      creationBlockedReason!,
                      style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              final tablePicker = DropdownButtonFormField<String>(
                value: selectedTable,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Funcionalidad o tabla', prefixIcon: Icon(Icons.table_chart_rounded), isDense: true),
                items: [
                  for (final table in tables)
                    DropdownMenuItem<String>(
                      value: table['table']?.toString(),
                      child: Text('${table['title'] ?? table['table']} · ${table['recordCount'] ?? 0}', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: onTableChanged,
              );
              final search = TextField(
                controller: searchController,
                onChanged: onSearch,
                decoration: const InputDecoration(labelText: 'Buscar registros', prefixIcon: Icon(Icons.search_rounded), isDense: true),
              );
              if (compact) return Column(children: [tablePicker, const SizedBox(height: 10), search]);
              return Row(children: [Expanded(flex: 4, child: tablePicker), const SizedBox(width: 12), Expanded(flex: 5, child: search)]);
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label, required this.palette});
  final IconData icon;
  final String label;
  final AppPalette palette;
  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: palette.background.withOpacity(.56),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: palette.primary), const SizedBox(width: 7), Text(label, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 11.5))]),
      );
}

class _RecordEditorSheet extends ConsumerStatefulWidget {
  const _RecordEditorSheet({
    required this.table,
    required this.title,
    required this.record,
    required this.columns,
    required this.primaryKeys,
    required this.creating,
  });

  final String table;
  final String title;
  final Map<String, dynamic> record;
  final List<Map<String, dynamic>> columns;
  final List<String> primaryKeys;
  final bool creating;

  @override
  ConsumerState<_RecordEditorSheet> createState() => _RecordEditorSheetState();
}

class _RecordEditorSheetState extends ConsumerState<_RecordEditorSheet> {
  final _reasonController = TextEditingController();
  final _deleteConfirmationController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final column in widget.columns) {
      final name = column['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      _controllers[name] = TextEditingController(text: widget.record[name]?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _deleteConfirmationController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final editable = widget.columns.where((column) => column['editable'] == true).toList();
    final insertable = widget.columns.where((column) => column['insertable'] == true).toList();
    final requiredCreate = insertable.where((column) => column['requiredOnCreate'] == true).toList();
    final optionalCreate = insertable.where((column) => column['requiredOnCreate'] != true).toList();
    final protectedColumns = widget.columns.where((column) => column['editable'] != true).toList();
    final saveEnabled = widget.creating ? insertable.isNotEmpty : editable.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: .92,
      minChildSize: .58,
      maxChildSize: .97,
      expand: false,
      builder: (context, scrollController) => Material(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.cardBorder))),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: palette.primary.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
                    child: Icon(widget.creating ? Icons.add_rounded : Icons.edit_note_rounded, color: palette.primary),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.creating ? 'Crear registro de ${widget.title}' : 'Registro de ${widget.title}',
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                        Text(
                          widget.creating
                              ? 'Completa los campos funcionales. Las claves y fechas técnicas se generan cuando corresponda.'
                              : widget.table,
                          style: TextStyle(color: palette.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(18),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ErrorBox(error: _error!, onRetry: () => setState(() => _error = null), palette: palette),
                    ),
                  if (widget.creating) ...[
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: palette.primary.withOpacity(.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.primary.withOpacity(.14)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, color: palette.primary, size: 20),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'La creación respeta llaves foráneas, restricciones únicas y valores predeterminados de PostgreSQL. Para imágenes, credenciales y flujos comerciales usa la vista funcional del módulo.',
                              style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.38),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (requiredCreate.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _EditorSection(
                        title: 'Información obligatoria',
                        subtitle: 'Estos campos deben completarse para crear el registro.',
                        palette: palette,
                        children: [
                          for (final column in requiredCreate)
                            _DynamicField(
                              column: column,
                              controller: _controllers[column['name']?.toString()]!,
                              required: true,
                            ),
                        ],
                      ),
                    ],
                    if (optionalCreate.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _EditorSection(
                        title: 'Información opcional',
                        subtitle: 'Los campos vacíos usarán el valor predeterminado o quedarán sin información.',
                        palette: palette,
                        children: [
                          for (final column in optionalCreate)
                            _DynamicField(
                              column: column,
                              controller: _controllers[column['name']?.toString()]!,
                            ),
                        ],
                      ),
                    ],
                  ] else ...[
                    _EditorSection(
                      title: 'Identificación y campos protegidos',
                      subtitle: 'Las claves, secretos e imágenes no se modifican desde este explorador.',
                      palette: palette,
                      children: [
                        for (final column in protectedColumns)
                          _ReadOnlyValue(
                            label: column['label']?.toString() ?? column['name'].toString(),
                            value: _display(widget.record[column['name']?.toString()]),
                            primary: column['primaryKey'] == true,
                            sensitive: column['sensitive'] == true,
                            palette: palette,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _EditorSection(
                      title: 'Campos modificables',
                      subtitle: 'Cada cambio queda registrado en la auditoría de soporte.',
                      palette: palette,
                      children: [
                        for (final column in editable)
                          _DynamicField(
                            column: column,
                            controller: _controllers[column['name']?.toString()]!,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: widget.creating ? 'Motivo o referencia de creación' : 'Motivo del cambio',
                      hintText: widget.creating ? 'Ej. Alta solicitada por soporte del cliente' : 'Ej. Corrección solicitada por el cliente',
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                  ),
                  if (!widget.creating && widget.table == 'usuarios') ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _unlockUser,
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: const Text('Desbloquear y reactivar usuario'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    ),
                  ],
                  if (!widget.creating) ...[
                    const SizedBox(height: 18),
                    ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: BorderSide(color: Colors.red.withOpacity(.18))),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: BorderSide(color: Colors.red.withOpacity(.18))),
                      title: const Text('Eliminación definitiva', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
                      subtitle: const Text('Solo cuando no exista una alternativa funcional o de inactivación.'),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [
                        TextField(
                          controller: _deleteConfirmationController,
                          decoration: InputDecoration(labelText: 'Escribe ELIMINAR ${widget.table.toUpperCase()}', prefixIcon: const Icon(Icons.warning_amber_rounded)),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _delete,
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text('Eliminar definitivamente'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, minimumSize: const Size(0, 40)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(color: palette.surface, border: Border(top: BorderSide(color: palette.cardBorder))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving || !saveEnabled ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(widget.creating ? Icons.add_rounded : Icons.save_rounded, size: 18),
                    label: Text(_saving ? 'Guardando' : widget.creating ? 'Crear registro' : 'Guardar cambios'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 15)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> get _keys => <String, dynamic>{
        for (final key in widget.primaryKeys) key: widget.record[key],
      };

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.creating) {
        final values = <String, dynamic>{};
        final missingLabels = <String>[];
        for (final column in widget.columns.where((item) => item['insertable'] == true)) {
          final name = column['name']?.toString() ?? '';
          final text = _controllers[name]?.text.trim() ?? '';
          if (column['requiredOnCreate'] == true && text.isEmpty) {
            missingLabels.add(column['label']?.toString() ?? name);
            continue;
          }
          if (text.isNotEmpty) values[name] = _parseValue(text, column['dataType']?.toString());
        }
        if (missingLabels.isNotEmpty) {
          throw Exception('Completa: ${missingLabels.join(', ')}');
        }
        await ref.read(adminSupportRepositoryProvider).createRecord(
              table: widget.table,
              values: values,
              reason: _reasonController.text.trim(),
            );
      } else {
        final changes = <String, dynamic>{};
        for (final column in widget.columns.where((item) => item['editable'] == true)) {
          final name = column['name']?.toString() ?? '';
          final text = _controllers[name]?.text ?? '';
          changes[name] = _parseValue(text, column['dataType']?.toString());
        }
        await ref.read(adminSupportRepositoryProvider).updateRecord(
              table: widget.table,
              keys: _keys,
              changes: changes,
              reason: _reasonController.text.trim(),
            );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.creating ? 'Registro creado y auditado.' : 'Registro actualizado y auditado.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(adminSupportRepositoryProvider).deleteRecord(
            table: widget.table,
            keys: _keys,
            confirmation: _deleteConfirmationController.text,
            reason: _reasonController.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro eliminado y auditado.')));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _unlockUser() async {
    final id = int.tryParse(widget.record['usua_id']?.toString() ?? '');
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminSupportRepositoryProvider).unlockUser(id);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario desbloqueado y reactivado.')));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({required this.title, required this.subtitle, required this.palette, required this.children});
  final String title;
  final String subtitle;
  final AppPalette palette;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: palette.panelDecoration(baseRadius: 19),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 11.5)), const SizedBox(height: 12), LayoutBuilder(builder: (context, constraints) { final width = constraints.maxWidth >= 700 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth; return Wrap(spacing: 12, runSpacing: 12, children: [for (final child in children) SizedBox(width: width, child: child)]); })]),
    );
  }
}

class _DynamicField extends StatelessWidget {
  const _DynamicField({required this.column, required this.controller, this.required = false});
  final Map<String, dynamic> column;
  final TextEditingController controller;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final type = column['dataType']?.toString().toLowerCase() ?? '';
    final label = '${column['label']?.toString() ?? column['name'].toString()}${required ? ' *' : ''}';
    if (type == 'boolean') {
      final normalized = controller.text.trim().toLowerCase();
      final value = normalized.isEmpty
          ? null
          : (const {'true', '1', 'si', 'sí'}.contains(normalized) ? 'true' : 'false');
      return DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, helperText: 'Sí / No', isDense: true),
        items: const [
          DropdownMenuItem(value: 'true', child: Text('Sí')),
          DropdownMenuItem(value: 'false', child: Text('No')),
        ],
        onChanged: (newValue) => controller.text = newValue ?? '',
      );
    }
    final isNumber = type.contains('numeric') || type.contains('integer') || type.contains('decimal') || type == 'real' || type.contains('double');
    final isDate = type == 'date';
    final isDateTime = type.contains('timestamp');
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
      maxLines: type.contains('text') ? 2 : 1,
      decoration: InputDecoration(
        labelText: label,
        helperText: isDate
            ? 'Formato: 2026-07-26'
            : isDateTime
                ? 'Formato: 2026-07-26T08:30:00'
                : type,
        isDense: true,
      ),
    );
  }
}

class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue({required this.label, required this.value, required this.primary, required this.sensitive, required this.palette});
  final String label;
  final String value;
  final bool primary;
  final bool sensitive;
  final AppPalette palette;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: palette.background.withOpacity(.55), borderRadius: BorderRadius.circular(13), border: Border.all(color: palette.cardBorder)),
      child: Row(children: [Icon(sensitive ? Icons.visibility_off_rounded : primary ? Icons.lock_outline_rounded : Icons.lock_outline_rounded, size: 17, color: primary ? palette.primary : palette.textSecondary), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 10.5)), Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5))]))]),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.columns, required this.primaryKeys, required this.palette, required this.onTap});
  final Map<String, dynamic> record;
  final List<Map<String, dynamic>> columns;
  final List<String> primaryKeys;
  final AppPalette palette;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: palette.panelDecoration(baseRadius: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.table_chart_rounded, color: palette.primary, size: 20), const SizedBox(width: 8), Expanded(child: Text(primaryKeys.map((key) => '$key: ${_display(record[key])}').join(' · '), style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900))), Icon(Icons.chevron_right_rounded, color: palette.textSecondary)]), const Divider(height: 18), for (final column in columns.take(5)) Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 125, child: Text(column['label']?.toString() ?? '', style: TextStyle(color: palette.textSecondary, fontSize: 11))), Expanded(child: Text(_display(record[column['name']?.toString()]), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)))]))]),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({required this.palette, required this.page, required this.totalPages, required this.total, required this.onPrevious, required this.onNext});
  final AppPalette palette;
  final int page;
  final int totalPages;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(color: palette.surface, border: Border(top: BorderSide(color: palette.cardBorder))),
      child: Row(children: [Text('$total registros', style: TextStyle(color: palette.textSecondary, fontSize: 12)), const Spacer(), IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left_rounded), tooltip: 'Anterior'), Text(totalPages <= 0 ? '0 / 0' : '${page + 1} / $totalPages', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800)), IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded), tooltip: 'Siguiente')]),
    );
  }
}

class _EmptyExplorer extends StatelessWidget {
  const _EmptyExplorer({required this.palette});
  final AppPalette palette;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.inbox_rounded, color: palette.textSecondary, size: 52), const SizedBox(height: 10), Text('No hay registros para mostrar', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800)), Text('Cambia la tabla o ajusta la búsqueda.', style: TextStyle(color: palette.textSecondary))]));
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error, required this.onRetry, required this.palette});
  final String error;
  final VoidCallback onRetry;
  final AppPalette palette;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withOpacity(.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.red.withOpacity(.18))), child: Row(children: [const Icon(Icons.error_outline_rounded, color: Colors.red), const SizedBox(width: 8), Expanded(child: Text(error, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontSize: 12))), TextButton(onPressed: onRetry, child: const Text('Reintentar'))]));
}

List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const <Object?>[]).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
List<Map<String, dynamic>> _visibleColumns(List<Map<String, dynamic>> columns) {
  final priority = columns.where((column) => column['primaryKey'] == true).toList();
  for (final column in columns) {
    if (priority.length >= 8) break;
    if (!priority.contains(column) && column['sensitive'] != true && column['largeContent'] != true) priority.add(column);
  }
  return priority;
}
int _asInt(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
String _display(Object? value) => value == null || value.toString().isEmpty ? '—' : value.toString();
Object? _parseValue(String text, String? dataType) {
  final value = text.trim();
  if (value.isEmpty) return null;
  final type = dataType?.toLowerCase() ?? '';
  if (type.contains('integer') || type == 'smallint' || type == 'bigint') return int.tryParse(value) ?? value;
  if (type.contains('numeric') || type.contains('decimal') || type == 'real' || type.contains('double')) return double.tryParse(value.replaceAll(',', '.')) ?? value;
  if (type == 'boolean') return const {'true', '1', 'si', 'sí'}.contains(value.toLowerCase());
  return value;
}
