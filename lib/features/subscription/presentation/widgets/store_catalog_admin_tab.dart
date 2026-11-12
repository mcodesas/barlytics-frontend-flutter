import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/providers/core_providers.dart';

/// Configuración de tienda exclusiva de la administración de BarLytics.
/// El backend exige un rol GLOBAL; ocultar botones no sustituye esa regla.
class StoreCatalogAdminTab extends ConsumerStatefulWidget {
  const StoreCatalogAdminTab({super.key});

  @override
  ConsumerState<StoreCatalogAdminTab> createState() => _StoreCatalogAdminTabState();
}

class _StoreCatalogAdminTabState extends ConsumerState<StoreCatalogAdminTab> {
  static const _path = '/api/v1/subscriptions/store/admin';

  bool _loading = true;
  bool _syncing = false;
  String? _error;
  Map<String, dynamic> _readiness = {};
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _history = [];
  bool _showHistory = false;
  String _search = '';
  final _priceFormat = NumberFormat.currency(
      locale: 'es_CO', symbol: r'$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  static Map<String, dynamic> _toMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Map<String, dynamic>> _toList(Object? value) =>
      value is List ? value.whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false) : <Map<String, dynamic>>[];

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final config = await api.get<Map<String, dynamic>>(
          '$_path/readiness', _toMap);
      final plans = await api.get<List<Map<String, dynamic>>>(
          '$_path/catalog', _toList);
      if (!mounted) return;
      setState(() {
        _readiness = config.data ?? {};
        _plans = plans.data ?? [];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadHistory() async {
    try {
      final response = await ref.read(apiClientProvider)
          .get<List<Map<String, dynamic>>>('$_path/history', _toList);
      if (mounted) setState(() => _history = response.data ?? []);
    } catch (error) {
      if (mounted) _notify('No fue posible cargar la auditoría: $error', error: true);
    }
  }

  void _notify(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), backgroundColor: error ? Colors.red.shade800 : null,
    ));
  }

  static String _string(Object? value, [String fallback = '']) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static num _number(Object? value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> _synchronize(Map<String,dynamic> plan, String provider) async {
    if (_syncing || _readiness['catalogEnabled'] != true) return;
    final key = provider == 'APPLE' ? 'apple' : 'google';
    final configured = _readiness['${key}Configured'] == true;
    if (!configured) {
      _notify('Faltan credenciales para ${provider == 'APPLE' ? 'App Store Connect' : 'Google Play'}.',
          error: true);
      return;
    }

    final currentSku = _string(plan['${key}Sku']);
    final controller = TextEditingController(text: currentSku);
    final isNew = currentSku.isEmpty;
    bool createProduct = isNew;
    bool applyPrice = isNew;
    bool activateGoogle = false;
    bool acceptConvertedPrice = false;
    final changes = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, change) => AlertDialog(
          title: Row(children: [
            Icon(provider == 'APPLE' ? Icons.apple : Icons.android_rounded),
            const SizedBox(width: 10),
            Expanded(child: Text('Sincronizar con ${provider == 'APPLE' ? 'App Store' : 'Google Play'}',
                style: const TextStyle(fontSize: 18))),
          ]),
          content: SizedBox(width: 450, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_string(plan['name']), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text('Precio mensual de BarLytics: ${_priceFormat.format(_number(plan['monthlyPrice']))} COP'),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  enabled: isNew,
                  inputFormatters: [LengthLimitingTextInputFormatter(150)],
                  decoration: InputDecoration(
                    labelText: 'Identificador del producto (SKU)',
                    border: const OutlineInputBorder(),
                    helperMaxLines: 3,
                    helperText: isNew
                        ? 'Opcional. Déjalo vacío para generar un identificador estable.'
                        : 'Los identificadores publicados no pueden cambiarse.',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  title: const Text('Crear producto si no existe'),
                  subtitle: const Text('La operación se hace en la API oficial de la tienda.'),
                  value: createProduct,
                  onChanged: (value) => change(() => createProduct = value),
                  contentPadding: EdgeInsets.zero,
                ),
                if (provider == 'APPLE')
                  SwitchListTile.adaptive(
                    title: const Text('Configurar precio COP autorizado'),
                    subtitle: const Text('Solo un precio exacto del catálogo de Apple; nunca aproximado.'),
                    value: applyPrice,
                    onChanged: (value) => change(() => applyPrice = value),
                    contentPadding: EdgeInsets.zero,
                  )
                else ...[
                  SwitchListTile.adaptive(
                    title: const Text('Activar plan base mensual en Google'),
                    subtitle: const Text('Habilita nuevas suscripciones en la región Colombia.'),
                    value: activateGoogle,
                    onChanged: (value) => change(() => activateGoogle = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile.adaptive(
                    title: const Text('Aceptar precio regional convertido'),
                    subtitle: const Text('Google puede calcular un valor final distinto por impuestos y reglas locales.'),
                    value: acceptConvertedPrice,
                    onChanged: (value) => change(() => acceptConvertedPrice = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
                const SizedBox(height: 10),
                const Text('La tienda conserva el control sobre revisiones, '
                    'moneda, disponibilidad y cambios de precio de los suscriptores.',
                  style: TextStyle(fontSize: 12)),
              ]),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton.icon(
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Confirmar sincronización'),
              onPressed: () => Navigator.pop(context, <String, dynamic>{
                'provider': provider,
                'sku': controller.text.trim(),
                'create': createProduct,
                'applyPrice': applyPrice,
                'activateGoogle': activateGoogle,
                'acceptConvertedPrice': acceptConvertedPrice,
              }),
            ),
          ],
        ),
      ),
    );
    // El identificador de la ruta no lo puede elegir el cliente:
    // se toma exclusivamente del catálogo autenticado.
    // El Future del diálogo puede completar antes de terminar su animación
    // inversa. No liberar el controlador mientras TextField siga en el árbol.
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    if (changes == null || !mounted) return;
    final id = _number(plan['planId']).toInt();
    if (id <= 0) return;
    setState(() => _syncing = true);
    try {
      final response = await ref.read(apiClientProvider)
          .post<Map<String, dynamic>>('$_path/catalog/$id/sync', changes, _toMap);
      if (!mounted) return;
      final result = response.data ?? {};
      _notify('${provider == 'APPLE' ? 'App Store' : 'Google Play'}: '
          '${_string(result['state'], 'Sin estado')}. '
          '${_string(result['detail'])}');
      await _load();
    } catch (error) {
      _notify('No fue posible sincronizar el producto: $error', error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _openSettings(String provider) async {
    final url = provider == 'APPLE'
        ? 'https://appstoreconnect.apple.com/'
        : 'https://play.google.com/console/';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _statusTile(AppPalette palette, String label, String value,
      IconData icon, bool ready) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: palette.panelDecoration(baseRadius: 15, elevated: false),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 19, color: ready ? palette.success : palette.textSecondary),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(fontSize: 11,
                color: palette.textSecondary)),
            Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textPrimary,
                    fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _platformCard(AppPalette palette,Map<String, dynamic> plan,
      String provider) {
    final apple = provider == 'APPLE';
    final key = apple ? 'apple' : 'google';
    final configured = _readiness['${key}Configured'] == true;
    final sku = _string(plan['${key}Sku']);
    final state = _string(plan['${key}Status'], 'SIN SINCRONIZAR');
    final enabled = plan['${key}Enabled'] == true;
    final price = plan['${key}Price'];
    final issue = _string(plan['${key}Error']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(apple ? Icons.apple : Icons.android_rounded,
              size: 23, color: palette.textPrimary),
          const SizedBox(width: 9),
          Expanded(child: Text(apple ? 'App Store' : 'Google Play',
              style: TextStyle(color: palette.textPrimary,
                  fontSize: 15,fontWeight: FontWeight.w900))),
          Icon(enabled ? Icons.check_circle_rounded : Icons.pending_outlined,
              color: enabled ? palette.success : palette.textSecondary,size: 18),
        ]),
        const SizedBox(height: 8),
        Text(state, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: enabled ? palette.success : palette.primary,
                fontWeight: FontWeight.w800, fontSize: 12)),
        if (sku.isNotEmpty) ...[
          const SizedBox(height: 5),
          Row(children: [
            Expanded(child: Text(sku,maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color:palette.textSecondary,fontSize: 11))),
            IconButton(
              tooltip:'Copiar SKU',icon:const Icon(Icons.copy_rounded,size:16),
              onPressed:()=>Clipboard.setData(ClipboardData(text:sku))),
          ]),
        ] else ...[
          const SizedBox(height: 10),
          Text('No vinculado a un producto',
              style: TextStyle(color:palette.textSecondary,fontSize: 12)),
        ],
        if (price != null) ...[
          const SizedBox(height: 6),
          Text('Precio en tienda: ${_priceFormat.format(_number(price))} COP',
              style: TextStyle(color:palette.textPrimary,fontSize: 12)),
        ],
        if (issue.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(issue,maxLines: 3,overflow:TextOverflow.ellipsis,
              style: TextStyle(color:palette.danger,fontSize: 11)),
        ],
        const SizedBox(height: 13),
        FilledButton.tonalIcon(
          onPressed: _syncing || !configured ||
                  _readiness['catalogEnabled'] != true ? null
                  : () => _synchronize(plan, provider),
          icon: const Icon(Icons.sync_rounded,size:18),
          label: Text(sku.isEmpty ? 'Crear y sincronizar' : 'Verificar / sincronizar'),
        ),
        if (!configured) Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Text('Configura primero el acceso a la API de la tienda.',
              style: TextStyle(color:palette.textSecondary,fontSize:11)),
        ),
      ]),
    );
  }

  Widget _planCard(AppPalette palette,Map<String,dynamic> plan) {
    final name = _string(plan['name']);
    return LayoutBuilder(builder:(context,constraints) {
      final wide=constraints.maxWidth>=730;
      return Container(
        padding: const EdgeInsets.all(17),
        decoration: palette.panelDecoration(baseRadius: 20, elevated: false),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[
          Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Container(padding:const EdgeInsets.all(11),
                decoration:BoxDecoration(color:palette.primary.withOpacity(.12),
                    borderRadius:BorderRadius.circular(14)),
                child:Icon(Icons.workspace_premium_rounded,color:palette.primary)),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(name,style:TextStyle(color:palette.textPrimary,
                  fontWeight:FontWeight.w900,fontSize:17)),
              Text(_string(plan['code']),maxLines:1,
                  overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:palette.textSecondary,fontSize:11)),
            ])),
            const SizedBox(width:6),
            Flexible(child:Text('${_priceFormat.format(_number(plan['monthlyPrice']))} COP / mes',
                textAlign:TextAlign.right,
                style:TextStyle(color:palette.textPrimary,fontWeight:FontWeight.w800,
                    fontSize:12))),
          ]),
          const SizedBox(height:13),
          if (wide)
            Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Expanded(child:_platformCard(palette,plan,'APPLE')),
              const SizedBox(width:12),
              Expanded(child:_platformCard(palette,plan,'GOOGLE')),
            ])
          else
            Column(children:[
              _platformCard(palette,plan,'APPLE'),
              const SizedBox(height:10),
              _platformCard(palette,plan,'GOOGLE'),
            ]),
        ]),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette=ref.watch(selectedAppPaletteProvider);
    if(_loading) return const Center(child:CircularProgressIndicator());
    if(_error!=null) return Center(child:Column(
      mainAxisSize:MainAxisSize.min,children:[
        Icon(Icons.cloud_off_outlined,size:45,color:palette.textSecondary),
        const SizedBox(height:8),
        Padding(padding:const EdgeInsets.all(20),
            child:Text(_error!,textAlign:TextAlign.center)),
        TextButton.icon(onPressed:_load,icon:const Icon(Icons.refresh),
            label:const Text('Reintentar')),
      ]));
    final plans=_plans.where((p)=>'${p['name']} ${p['code']}'
        .toLowerCase().contains(_search.toLowerCase())).toList();
    return RefreshIndicator(
      onRefresh:_load,
      child: ListView(
        padding:const EdgeInsets.fromLTRB(16,16,16,30),
        children:[
          Container(
            padding:const EdgeInsets.all(20),
            decoration:palette.panelDecoration(baseRadius:24,tint:palette.primary),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                Icon(Icons.sync_alt_rounded,size:28,color:palette.primary),
                const SizedBox(width:9),
                Expanded(child:Text('App Store y Google Play',
                    style:TextStyle(color:palette.textPrimary,fontSize:20,
                        fontWeight:FontWeight.w900))),
              ]),
              const SizedBox(height:8),
              Text('Parametriza tus planes mensuales una sola vez en BarLytics '
                  'y sincroniza los productos oficiales. Precio, aprobación y '
                  'disponibilidad se confirman por tienda.',
                  style:TextStyle(color:palette.textSecondary,height:1.4)),
              const SizedBox(height:14),
              Wrap(spacing:9,runSpacing:9,children:[
                _statusTile(palette,'Sincronización',
                    _readiness['catalogEnabled']==true?'Habilitada':'Deshabilitada',
                    Icons.sync_rounded,_readiness['catalogEnabled']==true),
                _statusTile(palette,'Apple API',
                    _readiness['appleConfigured']==true?'Configurada':'Pendiente',
                    Icons.apple,_readiness['appleConfigured']==true),
                _statusTile(palette,'Google API',
                    _readiness['googleConfigured']==true?'Configurada':'Pendiente',
                    Icons.android_rounded,_readiness['googleConfigured']==true),
                _statusTile(palette,'Cobros reales',
                    _readiness['checkoutEnabled']==true?'Habilitados':'Deshabilitados',
                    Icons.credit_card_rounded,_readiness['checkoutEnabled']==true),
              ]),
              if (_readiness['catalogEnabled']!=true) ...[
                const SizedBox(height:11),
                Text('La sincronización se habilita en el servidor con '
                    'BARLYTICS_IAP_CATALOG_SYNC_ENABLED=true. No activa cobros.',
                    style:TextStyle(color:palette.textSecondary,fontSize:12)),
              ],
              const SizedBox(height:12),
              Wrap(spacing:8,runSpacing:8,children:[
                OutlinedButton.icon(
                  onPressed:()=>_openSettings('APPLE'),
                  icon:const Icon(Icons.open_in_new,size:17),
                  label:const Text('App Store Connect')),
                OutlinedButton.icon(
                  onPressed:()=>_openSettings('GOOGLE'),
                  icon:const Icon(Icons.open_in_new,size:17),
                  label:const Text('Play Console')),
                OutlinedButton.icon(
                  onPressed:_syncing?null:_load,
                  icon:const Icon(Icons.refresh_rounded,size:17),
                  label:const Text('Actualizar')),
              ]),
            ]),
          ),
          const SizedBox(height:17),
          TextField(
            onChanged:(x)=>setState(()=>_search=x),
            decoration:const InputDecoration(
              labelText:'Buscar planes mensuales',
              prefixIcon:Icon(Icons.search_rounded)),
          ),
          const SizedBox(height:12),
          if (plans.isEmpty)
            Padding(padding:const EdgeInsets.all(24),
                child:Center(child:Text('No se encontraron planes mensuales.',
                    style:TextStyle(color:palette.textSecondary))))
          else
            for(final plan in plans) ...[
              _planCard(palette,plan),
              const SizedBox(height:12),
            ],
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:Text('Historial de sincronizaciones',
                style:TextStyle(color:palette.textPrimary,
                    fontWeight:FontWeight.w900,fontSize:15))),
            TextButton.icon(
              onPressed:() async {
                if(!_showHistory)await _loadHistory();
                if(mounted)setState(()=>_showHistory=!_showHistory);
              },
              icon:Icon(_showHistory?Icons.expand_less:Icons.history),
              label:Text(_showHistory?'Ocultar':'Ver historial')),
          ]),
          if(_showHistory)
            for(final item in _history.take(30))
              ListTile(
                contentPadding:EdgeInsets.zero,
                dense:true,
                leading:Icon(item['result']=='OK'
                    ?Icons.check_circle_outline:Icons.error_outline,
                    color:item['result']=='OK'?palette.success:palette.danger),
                title:Text('${_string(item['provider'])} · ${_string(item['action'])}',
                    maxLines:1,overflow:TextOverflow.ellipsis),
                subtitle:Text('${_string(item['sku'])} · ${_string(item['detail'])}',
                    maxLines:2,overflow:TextOverflow.ellipsis),
                trailing:Text(_string(item['result']),style:const TextStyle(fontSize:11)),
              ),
        ],
      ),
    );
  }
}
