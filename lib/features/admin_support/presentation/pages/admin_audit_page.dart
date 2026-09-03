import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../../data/admin_support_repository.dart';

class AdminAuditPage extends ConsumerStatefulWidget {
  const AdminAuditPage({super.key});

  @override
  ConsumerState<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends ConsumerState<AdminAuditPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  Map<String, dynamic> _data = const {};
  bool _loading = true;
  String? _error;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _page = 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(adminSupportRepositoryProvider).audit(
            page: _page,
            search: _searchController.text,
          );
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final rows = _maps(_data['records']);
    final total = _int(_data['total']);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: palette.panelDecoration(baseRadius: 23, tint: palette.primary),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: palette.primary.withOpacity(.10), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.history_rounded, color: palette.primary)),
                    const SizedBox(width: 11),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Auditoría de soporte', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)), Text('$total acciones registradas', style: TextStyle(color: palette.textSecondary, fontSize: 12))])),
                    IconButton(onPressed: _load, tooltip: 'Actualizar', icon: const Icon(Icons.refresh_rounded)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  maxLength: 120,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  controller: _searchController,
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
                  },
                  decoration: const InputDecoration(labelText: 'Buscar por administrador, tabla, acción o motivo', prefixIcon: Icon(Icons.search_rounded), isDense: true),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          Expanded(
            child: rows.isEmpty && !_loading
                ? Center(child: Text('No hay acciones registradas.', style: TextStyle(color: palette.textSecondary)))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _AuditCard(row: rows[index], palette: palette),
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: palette.surface, border: Border(top: BorderSide(color: palette.cardBorder))),
            child: Row(children: [Text('Página ${_page + 1}', style: TextStyle(color: palette.textSecondary)), const Spacer(), IconButton(onPressed: _page == 0 ? null : () { setState(() => _page--); _load(); }, icon: const Icon(Icons.chevron_left_rounded)), IconButton(onPressed: rows.length < 30 ? null : () { setState(() => _page++); _load(); }, icon: const Icon(Icons.chevron_right_rounded))]),
          ),
        ],
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.row, required this.palette});
  final Map<String, dynamic> row;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final action = row['action']?.toString() ?? '';
    final destructive = action.contains('DELETE');
    final color = destructive ? Colors.red : action.contains('UPDATE') ? Colors.orange : palette.primary;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: palette.cardBorder)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: palette.cardBorder)),
      backgroundColor: palette.surface.withOpacity(.76),
      collapsedBackgroundColor: palette.surface.withOpacity(.70),
      leading: CircleAvatar(backgroundColor: color.withOpacity(.10), child: Icon(destructive ? Icons.delete_outline_rounded : Icons.edit_note_rounded, color: color, size: 20)),
      title: Text('$action · ${row['table_name'] ?? ''}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
      subtitle: Text('${row['actor_email'] ?? ''} · ${row['created_at'] ?? ''}', style: TextStyle(color: palette.textSecondary, fontSize: 11.5)),
      children: [
        _JsonBlock(title: 'Clave', value: row['record_key'], palette: palette),
        _JsonBlock(title: 'Antes', value: row['before_data'], palette: palette),
        _JsonBlock(title: 'Después', value: row['after_data'], palette: palette),
        if ((row['reason']?.toString().trim().isNotEmpty ?? false))
          _JsonBlock(title: 'Motivo', value: row['reason'], palette: palette),
      ],
    );
  }
}

class _JsonBlock extends StatelessWidget {
  const _JsonBlock({required this.title, required this.value, required this.palette});
  final String title;
  final Object? value;
  final AppPalette palette;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 8), child: Container(width: double.infinity, padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: palette.background.withOpacity(.55), borderRadius: BorderRadius.circular(13)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800)), const SizedBox(height: 3), SelectableText(value?.toString() ?? '—', style: TextStyle(color: palette.textPrimary, fontSize: 11.5))])));
}

List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const <Object?>[]).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
int _int(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
