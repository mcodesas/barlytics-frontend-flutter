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

    final controller = messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 12),
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.radius(18)),
          side: BorderSide(
            color: palette.success.withOpacity(.42),
          ),
        ),
        elevation: 12,
        content: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: palette.success.withOpacity(.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: palette.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.titulo.isEmpty
                        ? 'Pedido listo'
                        : notification.titulo,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.mensaje,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: notification.mesaId == null ? 'VER VENTA' : 'VER MESA',
          textColor: palette.secondary,
          onPressed: () {
            _markRead(notification.id, branchId);
            ref.read(meseroSelectedModeProvider.notifier).state =
                MeseroPageMode.mesas;
            context.go('/mesero');
          },
        ),
      ),
    );

    controller.closed.whenComplete(() async {
      await _markRead(notification.id, branchId);
      if (!mounted) return;
      if (_showingId == notification.id) {
        setState(() => _showingId = null);
      }
      Future<void>.delayed(
        const Duration(milliseconds: 350),
        () => _check(),
      );
    });
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
  });

  final int id;
  final String tipo;
  final String titulo;
  final String mensaje;
  final int? ventaId;
  final int? cuentaId;
  final int? mesaId;

  factory _ReadyOrderNotification.fromJson(Map<String, dynamic> json) {
    return _ReadyOrderNotification(
      id: _asInt(json['id']) ?? 0,
      tipo: json['tipo']?.toString() ?? '',
      titulo: json['titulo']?.toString() ?? '',
      mensaje: json['mensaje']?.toString() ?? '',
      ventaId: _asInt(json['ventaId']),
      cuentaId: _asInt(json['cuentaId']),
      mesaId: _asInt(json['mesaId']),
    );
  }

  static int? _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
