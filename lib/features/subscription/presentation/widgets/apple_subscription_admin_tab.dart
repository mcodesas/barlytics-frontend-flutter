import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';

class AppleSubscriptionAdminTab extends ConsumerStatefulWidget {
  const AppleSubscriptionAdminTab({super.key});

  @override
  ConsumerState<AppleSubscriptionAdminTab> createState() => _AppleSubscriptionAdminTabState();
}

class _AppleSubscriptionAdminTabState extends ConsumerState<AppleSubscriptionAdminTab> {
  List<Map<String, dynamic>> _plans = const [];
  List<Map<String, dynamic>> _links = const [];
  List<Map<String, dynamic>> _remote = const [];
  bool _loading = true;
  bool _busy = false;
  bool _serverReady = false;
  bool _connectReady = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final plans = await api.get<List<Map<String, dynamic>>>(
        '/api/v1/subscriptions/admin/plans',
        (json) => (json as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
      );
      final data = await api.get<Map<String, dynamic>>(
        '/api/v1/subscriptions/admin/apple/config',
        (json) => Map<String, dynamic>.from(json as Map),
      );
      if (!mounted) return;
      final config = data.data ?? {};
      setState(() {
        _plans = plans.data ?? const [];
        _links = (config['mappings'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _serverReady = config['serverConfigured'] == true;
        _connectReady = config['connectConfigured'] == true;
        _notice = null;
      });
    } catch (error) {
      if (mounted) setState(() => _notice = 'Error consultando Apple: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _link(Object? id) {
    for (final row in _links) {
      if (row['planId']?.toString() == id?.toString()) return row;
    }
    return null;
  }

  Future<void> _action(Future<void> Function() work, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await work();
      if (mounted) setState(() => _notice = success);
    } catch (error) {
      if (mounted) setState(() => _notice = 'No se pudo completar la operación: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> plan) async {
    final mapping = _link(plan['id']);
    final product = TextEditingController(text: mapping?['productId']?.toString() ?? '');
    final group = TextEditingController(text: mapping?['groupId']?.toString() ?? '');
    bool active = mapping?['active'] != false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, redraw) => AlertDialog(
          title: const Text('Parametrizar App Store'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Plan: ' + (plan['name']?.toString() ?? 'BarLytics')),
                TextField(controller: product, decoration: const InputDecoration(
                  labelText: 'Product ID de Apple',
                  hintText: 'com.mcode.barlytics.pro.monthly',
                )),
                TextField(controller: group, decoration: const InputDecoration(
                  labelText: 'ID del grupo de suscripciones',
                )),
                SwitchListTile(
                  title: const Text('Activo para compras en iOS'),
                  value: active,
                  onChanged: (value) => redraw(() => active = value),
                ),
                const Text(
                  'Los precios y monedas se configuran por territorio en App Store '
                  'Connect, independientemente de Mercado Pago.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    final productId = product.text.trim();
    final groupId = group.text.trim();
    product.dispose();
    group.dispose();
    if (accepted != true || !mounted) return;
    await _action(() async {
      await ref.read(apiClientProvider).put(
        '/api/v1/subscriptions/admin/apple/plans/' + plan['id'].toString(),
        {'productId': productId, 'groupId': groupId, 'active': active},
        (json) => json,
      );
      await _reload();
    }, 'El identificador de Apple quedó vinculado al plan.');
  }

  Future<void> _sync(Map<String, dynamic> plan) async {
    await _action(() async {
      await ref.read(apiClientProvider).post(
        '/api/v1/subscriptions/admin/apple/plans/' + plan['id'].toString() + '/sync',
        const <String, dynamic>{},
        (json) => json,
      );
      await _reload();
    }, 'Producto sincronizado con App Store Connect.');
  }

  Future<void> _create(Map<String, dynamic> plan) async {
    final group = _link(plan['id'])?['groupId']?.toString() ?? '';
    if (group.isEmpty) {
      setState(() => _notice = 'Primero configura el ID del grupo de App Store.');
      return;
    }
    await _action(() async {
      await ref.read(apiClientProvider).post(
        '/api/v1/subscriptions/admin/apple/plans/' + plan['id'].toString() + '/create',
        {'groupId': group, 'groupLevel': 1},
        (json) => json,
      );
      await _reload();
    }, 'Producto creado. Completa precios y localización en App Store Connect.');
  }

  /// Consulta los precios oficiales y permite seleccionar el nivel de
  /// precio de Apple por territorio; jamás convierte el precio COP local.
  Future<void> _editPrice(Map<String, dynamic> plan) async {
    if (_busy) return;
    final territoryInput = TextEditingController(text: 'COL');
    final territory = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Territorio de Apple'),
        content: TextField(
          controller: territoryInput,
          maxLength: 3,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Código de territorio ISO3',
            hintText: 'COL',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, territoryInput.text.trim().toUpperCase()),
            child: const Text('Consultar precios'),
          ),
        ],
      ),
    );
    territoryInput.dispose();
    if (territory == null || !RegExp(r'^[A-Z]{3}$').hasMatch(territory) || !mounted) return;

    List<Map<String, dynamic>> prices;
    try {
      final response = await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
        '/api/v1/subscriptions/admin/apple/plans/' + plan['id'].toString() +
            '/price-points?territory=' + territory,
        (json) => (json as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
      );
      prices = response.data ?? const [];
    } catch (error) {
      if (mounted) setState(() => _notice = 'No fue posible consultar precios: $error');
      return;
    }
    if (!mounted) return;
    if (prices.isEmpty) {
      setState(() => _notice = 'Apple no devolvió niveles de precio para este país.');
      return;
    }

    String? chosen;
    bool preserve = true;
    final selected = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, rebuild) => AlertDialog(
          title: const Text('Precio oficial de App Store'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Plan: ' + (plan['name'] ?? '').toString()),
                Text('Territorio: ' + territory),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: chosen,
                  hint: const Text('Seleccionar precio'),
                  items: prices.map((row) => DropdownMenuItem<String>(
                    value: row['id']?.toString(),
                    child: Text((row['customerPrice'] ?? '').toString() +
                        ' · ingreso estimado ' + (row['proceeds'] ?? '').toString()),
                  )).toList(),
                  onChanged: (v) => rebuild(() => chosen = v),
                ),
                CheckboxListTile(
                  title: const Text('Preservar precio de suscriptores anteriores'),
                  subtitle: const Text('Para aumentos, según reglas de Apple.'),
                  value: preserve,
                  onChanged: (v) => rebuild(() => preserve = v ?? true),
                ),
                const Text(
                  'Cambiar precios puede afectar cobros futuros. '
                  'Apple gestionará avisos o consentimiento del suscriptor.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: chosen == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Revisar cambio'),
            ),
          ],
        ),
      ),
    );
    if (selected != true || chosen == null || !mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Aplicar precio en App Store?'),
        content: Text('El precio de Apple cambiará en ' + territory +
            '. Puede afectar a nuevas compras y futuras renovaciones.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No cambiar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar cambio'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final chosenId = chosen!;
    await _action(() async {
      await ref.read(apiClientProvider).post(
        '/api/v1/subscriptions/admin/apple/plans/' + plan['id'].toString() + '/price',
        {'territory': territory, 'pricePointId': chosenId, 'preserveCurrentPrice': preserve},
        (json) => json,
      );
    }, 'Precio actualizado en App Store Connect.');
  }

  Future<void> _catalog() async {
    await _action(() async {
      final response = await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
        '/api/v1/subscriptions/admin/apple/catalog',
        (json) => (json as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
      );
      if (mounted) setState(() => _remote = response.data ?? const []);
    }, 'Catálogo Apple actualizado.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('App Store Connect', style: theme.textTheme.titleLarge),
        const Text('Administra los Product ID de Apple por plan de BarLytics sin modificar Mercado Pago.'),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(_serverReady ? Icons.verified_outlined : Icons.warning_amber_outlined),
          title: Text('Verificación: ' + (_serverReady ? 'Configurada' : 'Sin configurar')),
          subtitle: Text('API administrativa: ' + (_connectReady ? 'Configurada' : 'Sin configurar')),
          trailing: IconButton(
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ),
        if (_notice != null) Padding(
          padding: const EdgeInsets.all(10),
          child: Text(_notice!, style: theme.textTheme.bodySmall),
        ),
        if (_busy) const LinearProgressIndicator(),
        for (final plan in _plans)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text((plan['name'] ?? 'Plan').toString(), style: theme.textTheme.titleMedium),
                  Text('Código: ' + (plan['code'] ?? '').toString()),
                  Text('Product ID: ' + (_link(plan['id'])?['productId'] ?? 'Sin vincular').toString()),
                  Text('Grupo Apple: ' + (_link(plan['id'])?['groupId'] ?? 'Sin grupo').toString()),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _edit(plan),
                        icon: const Icon(Icons.tune),
                        label: const Text('Parametrizar'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || !_connectReady || _link(plan['id']) == null
                            ? null : () => _sync(plan),
                        icon: const Icon(Icons.sync),
                        label: const Text('Sincronizar'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || !_connectReady || _link(plan['id']) == null
                            ? null : () => _create(plan),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Crear en Apple'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || !_connectReady ||
                                (_link(plan['id'])?['appleId']?.toString().isNotEmpty != true)
                            ? null : () => _editPrice(plan),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Precio por país'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy || !_connectReady ? null : _catalog,
          icon: const Icon(Icons.cloud_download_outlined),
          label: const Text('Consultar catálogo remoto'),
        ),
        for (final item in _remote)
          ListTile(
            title: Text((item['name'] ?? 'Producto Apple').toString()),
            subtitle: Text((item['productId'] ?? '').toString() +
                ' · ' + (item['period'] ?? '').toString() +
                ' · ' + (item['state'] ?? '').toString()),
          ),
        const Text(
          'Los productos requieren precio, disponibilidad y, cuando corresponda, '
          'revisión de Apple antes de poder venderse.',
        ),
      ],
    );
  }
}
).hasMatch(selectedTerritory)
        || !mounted) return;

    List<Map<String, dynamic>> prices;
    try {
      final result = await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
        '/api/v1/subscriptions/admin/apple/plans/' + plan['id'].toString() +
            '/price-points?territory=' + selectedTerritory,
        (json) => (json as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
      );
      prices = result.data ?? const [];
    } catch (error) {
      if (mounted) setState(() => _notice = 'No se pudieron cargar los precios de Apple: $error');
      return;
    }
    if (!mounted) return;
    if (prices.isEmpty) {
      setState(() => _notice = 'Apple no devolvió precios para este territorio.');
      return;
    }

    String? selected;
    bool preserve = true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, rebuild) => AlertDialog(
          title: const Text('Seleccionar precio oficial de Apple'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Plan: ' + (plan['name'] ?? '').toString()),
                Text('Territorio: ' + selectedTerritory),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selected,
                  hint: const Text('Selecciona precio de Apple'),
                  items: prices.map((p) => DropdownMenuItem<String>(
                    value: p['id']?.toString(),
                    child: Text((p['customerPrice'] ?? '').toString() +
                        ' · ingreso estimado ' + (p['proceeds'] ?? '').toString()),
                  )).toList(),
                  onChanged: (value) => rebuild(() => selected = value),
                ),
                CheckboxListTile(
                  title: const Text('Conservar precio anterior a suscriptores existentes'),
                  subtitle: const Text('Aplica para aumentos cuando Apple lo permite.'),
                  value: preserve,
                  onChanged: (value) => rebuild(() => preserve = value ?? true),
                ),
                const Text(
                  'Los cambios pueden afectar renovaciones futuras. '
                  'Apple notificará al suscriptor cuando corresponda.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: selected == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Revisar cambio'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || selected == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Confirmar cambio de tarifa real?'),
        content: Text('Se configurará en App Store Connect el nivel '
            'de precio seleccionado para ' + selectedTerritory +
            '. Esta acción afecta compras futuras y podría afectar '
            'renovaciones de clientes actuales.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No cambiar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar en Apple'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final pricePointId = selected!;
    await _action(() async {
      await ref.read(apiClientProvider).post(
        '/api/v1/subscriptions/admin/apple/plans/' + plan['id'].toString() + '/price',
        {'territory': selectedTerritory, 'pricePointId': pricePointId,
         'preserveCurrentPrice': preserve},
        (json) => json,
      );
    }, 'Precio configurado correctamente en App Store Connect.');
  }

  Future<void> _catalog() async {
    await _action(() async {
      final result = await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
        '/api/v1/subscriptions/admin/apple/catalog',
        (json) => (json as List? ?? const []).whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row)).toList(),
      );
      if (mounted) setState(() => _remote = result.data ?? const []);
    }, 'Catálogo de Apple actualizado.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('App Store Connect', style: theme.textTheme.titleLarge),
        const Text('Administra los Product ID de Apple por plan de BarLytics sin modificar Mercado Pago.'),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(_serverReady ? Icons.verified_outlined : Icons.warning_amber_outlined),
          title: Text('Verificación: ' + (_serverReady ? 'Configurada' : 'Sin configurar')),
          subtitle: Text('API administrativa: ' + (_connectReady ? 'Configurada' : 'Sin configurar')),
          trailing: IconButton(
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ),
        if (_notice != null) Padding(
          padding: const EdgeInsets.all(10),
          child: Text(_notice!, style: theme.textTheme.bodySmall),
        ),
        if (_busy) const LinearProgressIndicator(),
        for (final plan in _plans)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text((plan['name'] ?? 'Plan').toString(), style: theme.textTheme.titleMedium),
                  Text('Código: ' + (plan['code'] ?? '').toString()),
                  Text('Product ID: ' + (_link(plan['id'])?['productId'] ?? 'Sin vincular').toString()),
                  Text('Grupo Apple: ' + (_link(plan['id'])?['groupId'] ?? 'Sin grupo').toString()),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _edit(plan),
                        icon: const Icon(Icons.tune),
                        label: const Text('Parametrizar'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || !_connectReady || _link(plan['id']) == null
                            ? null : () => _sync(plan),
                        icon: const Icon(Icons.sync),
                        label: const Text('Sincronizar'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || !_connectReady || _link(plan['id']) == null
                            ? null : () => _create(plan),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Crear en Apple'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy || !_connectReady ? null : _catalog,
          icon: const Icon(Icons.cloud_download_outlined),
          label: const Text('Consultar catálogo remoto'),
        ),
        for (final item in _remote)
          ListTile(
            title: Text((item['name'] ?? 'Producto Apple').toString()),
            subtitle: Text((item['productId'] ?? '').toString() +
                ' · ' + (item['period'] ?? '').toString() +
                ' · ' + (item['state'] ?? '').toString()),
          ),
        const Text(
          'Los productos requieren precio, disponibilidad y, cuando corresponda, '
          'revisión de Apple antes de poder venderse.',
        ),
      ],
    );
  }
}
