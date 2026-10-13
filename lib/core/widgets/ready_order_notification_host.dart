import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_palette.dart';
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
    extends ConsumerState<ReadyOrderNotificationHost> {
  Timer? _timer;
  bool _checking = false;
  int? _showingId;
  final Set<int> _markingRead = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (!mounted || _checking || _showingId != null) return;

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

      if (!mounted) return;
      final notifications =
          response.data ?? const <_ReadyOrderNotification>[];
      if (notifications.isEmpty) return;

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
                          onPressed: () {
                            ref
                                .read(meseroSelectedModeProvider.notifier)
                                .state = MeseroPageMode.mesas;
                            context.go('/mesero');
                          },
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
    if (_markingRead.contains(notificationId)) return;
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
  Widget build(BuildContext context) => widget.child;
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
