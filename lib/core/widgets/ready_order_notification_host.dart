import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_palette.dart';
import '../../features/intelligence/data/intelligence_api.dart';
import '../../features/navigation/presentation/providers/active_role_provider.dart';
import '../../features/navigation/presentation/providers/user_menu_provider.dart';
import '../../features/mesero/presentation/providers/mesero_tab_provider.dart';
import '../branch/branch_scope_provider.dart';
import '../providers/core_providers.dart';

class ReadyOrderNotificationHost extends ConsumerStatefulWidget {
  const ReadyOrderNotificationHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<ReadyOrderNotificationHost> createState() =>
      _ReadyOrderNotificationHostState();
}

class _ReadyOrderNotificationHostState
    extends ConsumerState<ReadyOrderNotificationHost> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _lastIntelligenceCheck;
  int _alertScope=0;
  bool _alertShowing=false,_foreground=true,_resolvingAlert=false;
  final AudioPlayer _alertPlayer = AudioPlayer();
  Uint8List? _alertTone;
  bool _checking = false;
  int? _showingId;
  final Set<int> _markingRead = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_alertPlayer.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    _foreground=state==AppLifecycleState.resumed;
    if(!_foreground)_invalidateIntelligence();
  }
  void _invalidateIntelligence(){
    _alertScope++;
    _lastIntelligenceCheck=null;
    if(_alertShowing&&mounted){
      _alertShowing=false;
      _showingId=null;
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    }
  }
  bool _canNotify()=>ref.read(userMenuProvider).valueOrNull?.any((m)=>m.keyName=='intelligence')??false;
  bool _activeAlert(int branch,int scope)=>mounted&&_foreground&&scope==_alertScope&&
      ref.read(branchScopeProvider).activeBranchId==branch&&_canNotify();
  Future<void> _checkIntelligence(int branch) async{
    if(!_foreground||!_canNotify())return;
    final now=DateTime.now();
    if(_lastIntelligenceCheck!=null&&now.difference(_lastIntelligenceCheck!)<const Duration(minutes:1))return;
    _lastIntelligenceCheck=now;
    final scope=_alertScope;
    final data=await ref.read(intelligenceApiProvider).alertNotifications(branch);
    if(!_activeAlert(branch,scope)||_showingId!=null)return;
    final rows=data['notifications'];
    if(rows is! List||rows.isEmpty||rows.first is! Map)return;
    final n=Map<String,dynamic>.from(rows.first as Map);
    final id=n['id'];
    if(id is! int||id<=0)return;
    _showingId=id;_alertShowing=true;
    final messenger=ScaffoldMessenger.of(context);
    final snack=messenger.showSnackBar(SnackBar(
      behavior:SnackBarBehavior.floating,duration:const Duration(seconds:20),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(n['title']?.toString()??'Intelligence',style:const TextStyle(fontWeight:FontWeight.bold)),
        Text(n['message']?.toString()??'Revisa las alertas de tu sucursal.'),
        Wrap(spacing:8,children:[
          TextButton(onPressed:()=>_resolveIntelligence(branch,scope,id,0,open:true),child:const Text('Ver alertas')),
          TextButton(onPressed:()=>_resolveIntelligence(branch,scope,id,3),child:const Text('3 min')),
          TextButton(onPressed:()=>_resolveIntelligence(branch,scope,id,5),child:const Text('5 min')),
          TextButton(onPressed:()=>_resolveIntelligence(branch,scope,id,0),child:const Text('Marcar leída')),
        ]),
      ]),
    ));
    unawaited(snack.closed.then((_){
      if(mounted&&_alertScope==scope&&_alertShowing&&_showingId==id){
        _alertShowing=false;_showingId=null;
      }
    }));
  }
  Future<void> _resolveIntelligence(int branch,int scope,int id,int minutes,{bool open=false})async{
    if(!_activeAlert(branch,scope)||_resolvingAlert)return;
    _resolvingAlert=true;
    try{
      final result=await ref.read(intelligenceApiProvider).resolveAlertNotification(branch,id,minutes);
      if(!_activeAlert(branch,scope))return;
      if(result['id']!=id||result['status']!=(minutes==0?'READ':'SNOOZED'))throw const FormatException('Aviso no confirmado');
      _alertShowing=false;_showingId=null;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if(open)context.go('/intelligence');
    }catch(_){
      if(_activeAlert(branch,scope)){
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _alertShowing=false;_showingId=null;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se confirmó la actualización del aviso.')));
      }
    }finally{_resolvingAlert=false;}
  }
  Future<void> _check() async {
    if (!mounted || !_foreground || _checking || _showingId != null) return;

    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) return;

    _checking = true;
    try {
      final response =
          await ref.read(apiClientProvider).get<List<_ReadyOrderNotification>>(
                '/api/v1/notificaciones',
                (json) => (json as List? ?? const <dynamic>[])
                    .whereType<Map>()
                    .map(
                      (item) => _ReadyOrderNotification.fromJson(
                        Map<String, dynamic>.from(item),
                      ),
                    )
                    .where((item) => item.id > 0)
                    .toList(growable: false),
                queryParameters: <String, dynamic>{
                  'sucursalId': branchId,
                },
              );

      if (!mounted || !_foreground || ref.read(branchScopeProvider).activeBranchId!=branchId) return;
      final notifications =
          response.data ?? const <_ReadyOrderNotification>[];
      if (notifications.isEmpty) {await _checkIntelligence(branchId);return;}

      final notification = notifications.first;
      _showingId = notification.id;
      _showNotification(notification, branchId);
    } catch (_) {
      // La consulta es secundaria a la operación. No interrumpimos al mesero
      // si temporalmente no se pueden consultar notificaciones.
    } finally {
      _checking = false;
    }
  }

  void _showNotification(
    _ReadyOrderNotification notification,
    int branchId,
  ) {
    if (!mounted) return;

    final palette = ref.read(selectedAppPaletteProvider);
    final messenger = ScaffoldMessenger.of(context);
    final compact = MediaQuery.sizeOf(context).width < 700;

    // Alerta inmediata en todos los ambientes soportados por Flutter.
    // En móvil, HapticFeedback agrega una señal física además del sonido.
    unawaited(_playAlert());
    unawaited(HapticFeedback.heavyImpact());

    final controller = messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 15),
        margin: EdgeInsets.fromLTRB(
          compact ? 12 : 28,
          10,
          compact ? 12 : 28,
          compact ? 14 : 24,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 22,
          vertical: compact ? 14 : 18,
        ),
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.radius(compact ? 20 : 24)),
          side: BorderSide(
            color: palette.success.withOpacity(.55),
            width: 1.5,
          ),
        ),
        elevation: 18,
        actionOverflowThreshold: .34,
        content: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: compact ? 96 : 112,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 50 : 60,
                height: compact ? 50 : 60,
                decoration: BoxDecoration(
                  color: palette.success.withOpacity(.14),
                  borderRadius: BorderRadius.circular(compact ? 15 : 18),
                  border: Border.all(
                    color: palette.success.withOpacity(.22),
                  ),
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: palette.success,
                  size: compact ? 27 : 32,
                ),
              ),
              SizedBox(width: compact ? 12 : 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRODUCTO LISTO',
                      style: TextStyle(
                        color: palette.success,
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 10.5 : 12,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.titulo.isEmpty
                          ? 'Pedido listo para entregar'
                          : notification.titulo,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 16 : 19,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: compact ? 5 : 7),
                    Text(
                      notification.mensaje,
                      maxLines: compact ? 3 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 13.5 : 15,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: compact ? 9 : 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openOrder(notification),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.secondary,
                            side: BorderSide(
                              color: palette.secondary.withOpacity(.42),
                            ),
                          ),
                          icon: Icon(
                            notification.mesaId == null
                                ? Icons.receipt_long_outlined
                                : Icons.table_restaurant_rounded,
                            size: 17,
                          ),
                          label: Text(
                            notification.mesaId == null
                                ? 'VER VENTA'
                                : 'VER MESA',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _snooze(
                            notification,
                            branchId,
                            3,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.warning,
                            side: BorderSide(
                              color: palette.warning.withOpacity(.42),
                            ),
                          ),
                          icon: const Icon(
                            Icons.snooze_rounded,
                            size: 17,
                          ),
                          label: const Text('3 MIN'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _snooze(
                            notification,
                            branchId,
                            5,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.warning,
                            side: BorderSide(
                              color: palette.warning.withOpacity(.42),
                            ),
                          ),
                          icon: const Icon(
                            Icons.more_time_rounded,
                            size: 17,
                          ),
                          label: const Text('5 MIN'),
                        ),
                        FilledButton.icon(
                          onPressed: notification.detalleId == null &&
                                  notification.cuentaId == null
                              ? null
                              : () => _confirmDelivered(
                                    notification,
                                    branchId,
                                  ),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.success,
                            foregroundColor:
                                palette.success.computeLuminance() > .52
                                    ? Colors.black
                                    : Colors.white,
                          ),
                          icon: const Icon(
                            Icons.room_service_rounded,
                            size: 18,
                          ),
                          label: const Text('ENTREGADO'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    controller.closed.whenComplete(() {
      if (!mounted) return;
      if (_showingId == notification.id) {
        setState(() => _showingId = null);
      }
      // Cerrar o dejar vencer el aviso no significa que el pedido fue
      // atendido. La notificación continúa pendiente hasta que el mesero
      // confirme ENTREGADO.
      Future<void>.delayed(
        const Duration(seconds: 8),
        () => _check(),
      );
    });
  }

  void _openOrder(_ReadyOrderNotification notification) {
    if (!mounted || !context.mounted) return;

    ref.read(meseroSelectedModeProvider.notifier).state =
        MeseroPageMode.mesas;

    if (!mounted || !context.mounted) return;
    context.go('/mesero');
  }

  Future<void> _playAlert() async {
    try {
      _alertTone ??= _buildAlertTone();
      await _alertPlayer.stop();
      await _alertPlayer.setVolume(1);
      await _alertPlayer.play(
        BytesSource(
          _alertTone!,
          mimeType: 'audio/wav',
        ),
      );
    } catch (_) {
      // El aviso visual sigue funcionando si el sistema/navegador bloquea
      // temporalmente la reproducción de audio.
    }
  }

  Uint8List _buildAlertTone() {
    const sampleRate = 22050;
    const channels = 1;
    const bitsPerSample = 16;
    const firstToneSeconds = .18;
    const pauseSeconds = .07;
    const secondToneSeconds = .26;

    final firstSamples = (sampleRate * firstToneSeconds).round();
    final pauseSamples = (sampleRate * pauseSeconds).round();
    final secondSamples = (sampleRate * secondToneSeconds).round();
    final totalSamples = firstSamples + pauseSamples + secondSamples;
    final dataLength = totalSamples * channels * (bitsPerSample ~/ 8);
    final bytes = ByteData(44 + dataLength);

    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, channels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(
      28,
      sampleRate * channels * (bitsPerSample ~/ 8),
      Endian.little,
    );
    bytes.setUint16(32, channels * (bitsPerSample ~/ 8), Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);

    var offset = 44;

    void writeTone(int sampleCount, double frequency) {
      for (var sample = 0; sample < sampleCount; sample++) {
        final progress = sample / sampleCount;
        final fade = progress < .08
            ? progress / .08
            : progress > .86
                ? (1 - progress) / .14
                : 1.0;
        final wave = math.sin(
          2 * math.pi * frequency * sample / sampleRate,
        );
        final value = (wave * 0.48 * fade.clamp(0.0, 1.0) * 32767).round();
        bytes.setInt16(offset, value, Endian.little);
        offset += 2;
      }
    }

    writeTone(firstSamples, 880);
    for (var sample = 0; sample < pauseSamples; sample++) {
      bytes.setInt16(offset, 0, Endian.little);
      offset += 2;
    }
    writeTone(secondSamples, 1175);

    return bytes.buffer.asUint8List();
  }

  Future<void> _snooze(
    _ReadyOrderNotification notification,
    int branchId,
    int minutes,
  ) async {
    if (!mounted || (minutes != 3 && minutes != 5)) return;

    try {
      await ref.read(apiClientProvider).put<Map<String, dynamic>>(
            '/api/v1/notificaciones/${notification.id}/recordar'
            '?sucursalId=$branchId&minutos=$minutes',
            null,
            (json) => Map<String, dynamic>.from(json as Map),
          );
      if (!mounted) return;

      setState(() => _showingId = null);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text(
            'Te recordaré este producto en $minutes minutos.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'No fue posible programar el recordatorio: $error',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelivered(
    _ReadyOrderNotification notification,
    int branchId,
  ) async {
    final detalleId = notification.detalleId;
    final cuentaId = notification.cuentaId;
    if ((detalleId == null && cuentaId == null) || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Confirmar entrega'),
        content: Text(
          '${notification.mensaje}\n\n¿Confirmas que este producto ya fue entregado a la mesa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Sí, entregado'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      if (detalleId != null) {
        await ref.read(apiClientProvider).put<Map<String, dynamic>>(
              '/api/v1/comandas/$detalleId/entregar'
              '?sucursalId=$branchId',
              null,
              (json) => Map<String, dynamic>.from(json as Map),
            );
      } else {
        await ref.read(apiClientProvider).put<int>(
              '/api/v1/comandas/cuenta/$cuentaId/entregar'
              '?sucursalId=$branchId',
              null,
              (json) {
                if (json is num) return json.toInt();
                return int.tryParse(json?.toString() ?? '') ?? 0;
              },
            );
      }
      if (!mounted) return;
      await _markRead(notification.id, branchId);
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Producto marcado como entregado a la mesa.'),
          ),
        );

      setState(() => _showingId = null);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'No fue posible marcar el producto como entregado: $error',
          ),
        ),
      );
    }
  }

  Future<void> _markRead(int notificationId, int branchId) async {
    if (!mounted || _markingRead.contains(notificationId)) return;
    _markingRead.add(notificationId);

    try {
      await ref.read(apiClientProvider).put<Map<String, dynamic>>(
            '/api/v1/notificaciones/$notificationId/leer'
            '?sucursalId=$branchId',
            null,
            (json) => Map<String, dynamic>.from(json as Map),
          );
    } catch (_) {
      // Si falla, permanecerá no leída y podrá volver a mostrarse.
    } finally {
      _markingRead.remove(notificationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedRolesProvider,(old,next){if(old!=next)_invalidateIntelligence();});
    ref.listen(branchScopeProvider,(old,next){if(old?.activeBranchId!=next.activeBranchId)_invalidateIntelligence();});
    ref.listen(userMenuProvider,(old,next){
      if(!(next.valueOrNull?.any((m)=>m.keyName=='intelligence')??false))_invalidateIntelligence();
    });
    return widget.child;
  }
}

class _ReadyOrderNotification {
  const _ReadyOrderNotification({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.ventaId,
    required this.cuentaId,
    required this.mesaId,
    required this.detalleId,
    required this.recordarEn,
  });

  final int id;
  final String tipo;
  final String titulo;
  final String mensaje;
  final int? ventaId;
  final int? cuentaId;
  final int? mesaId;
  final int? detalleId;
  final DateTime? recordarEn;

  factory _ReadyOrderNotification.fromJson(Map<String, dynamic> json) {
    return _ReadyOrderNotification(
      id: _asInt(json['id']) ?? 0,
      tipo: json['tipo']?.toString() ?? '',
      titulo: json['titulo']?.toString() ?? '',
      mensaje: json['mensaje']?.toString() ?? '',
      ventaId: _asInt(json['ventaId']),
      cuentaId: _asInt(json['cuentaId']),
      mesaId: _asInt(json['mesaId']),
      detalleId: _asInt(json['detalleId']),
      recordarEn: DateTime.tryParse(json['recordarEn']?.toString() ?? ''),
    );
  }

  static int? _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
