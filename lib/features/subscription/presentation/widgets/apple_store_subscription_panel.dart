import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/subscription_remote_datasource.dart';
import '../providers/subscription_provider.dart';

/// Compra de suscripciones auto-renovables en StoreKit.
/// El teléfono nunca puede activar su propio plan: la verificación y
/// titularidad de la compra se realizan en Spring Boot con la API de Apple.
class AppleStoreSubscriptionPanel extends ConsumerStatefulWidget {
  const AppleStoreSubscriptionPanel({super.key, this.onConfirmed});

  final Future<void> Function()? onConfirmed;

  @override
  ConsumerState<AppleStoreSubscriptionPanel> createState() =>
      _AppleStoreSubscriptionPanelState();
}

class _AppleStoreSubscriptionPanelState extends ConsumerState<AppleStoreSubscriptionPanel> {
  final InAppPurchase _store = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  List<_ApplePlan> _mapped = const [];
  Map<String, ProductDetails> _products = const {};
  bool _loading = true;
  bool _busy = false;
  String? _message;
  bool _serverReady = false;
  bool _blockedByMercadoPago = false;

  @override
  void initState() {
    super.initState();
    // Escuchar ANTES de consultar el catálogo y antes de comenzar la compra:
    // StoreKit también puede entregar transacciones previas no finalizadas.
    _purchaseSubscription = _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        if (mounted) setState(() {
          _busy = false;
          _message = 'No fue posible recuperar la compra de App Store: $error';
        });
      },
    );
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final response = await ref.read(apiClientProvider).get<List<_ApplePlan>>(
        '/api/v1/subscriptions/apple/products',
        (json) => (json as List? ?? const [])
            .whereType<Map>()
            .map((item) => _ApplePlan.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
      );
      final mapped = response.data ?? const <_ApplePlan>[];
      final ready = mapped.any((plan) => plan.backendReady);
      final current = await ref.read(subscriptionRemoteDataSourceProvider).current();
      final blocked = current.active &&
          current.provider?.toUpperCase() == 'MERCADOPAGO';
      if (!mounted) return;
      if (!await _store.isAvailable()) {
        throw StateError('La tienda App Store no está disponible en este dispositivo.');
      }
      if (mapped.isEmpty) {
        setState(() {
          _mapped = mapped;
          _serverReady = ready;
          _products = const {};
          _message = 'Los planes aún no están vinculados a productos de App Store.';
        });
        return;
      }
      final queried = await _store.queryProductDetails(
        mapped.map((item) => item.productId).toSet(),
      );
      if (queried.error != null) {
        throw StateError(queried.error!.message);
      }
      if (!mounted) return;
      setState(() {
        _mapped = mapped;
        _serverReady = ready;
        _blockedByMercadoPago = blocked;
        _products = {for (final product in queried.productDetails) product.id: product};
        if (queried.productDetails.isEmpty) {
          _message = 'Apple todavía no ofrece estos productos. Comprueba '
              'el grupo, los precios, el contrato comercial y la disponibilidad en App Store Connect.';
        } else if (!ready) {
          _message = 'Falta configurar la verificación de compras Apple en el servidor.';
        } else if (blocked) {
          _message = 'Hay un período pagado de Mercado Pago vigente. Cancela su renovación '
              'y espera hasta que finalice antes de contratar con Apple.';
        }
      });
    } catch (error) {
      if (mounted) setState(() => _message = 'No se pudo cargar App Store: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy(ProductDetails product) async {
    if (_busy || !_serverReady || _blockedByMercadoPago) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // Suscripciones se compran mediante buyNonConsumable en este plugin;
      // Apple las gestiona como auto-renovables según su Product ID.
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started && mounted) {
        setState(() {
          _busy = false;
          _message = 'App Store no pudo iniciar la transacción.';
        });
      }
    } catch (error) {
      if (mounted) setState(() {
        _busy = false;
        _message = 'No se pudo iniciar la compra: $error';
      });
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!mounted) return;
      if (purchase.status == PurchaseStatus.pending) {
        setState(() {
          _busy = true;
          _message = 'Esperando autorización de Apple…';
        });
        continue;
      }
      if (purchase.status == PurchaseStatus.canceled) {
        setState(() {
          _busy = false;
          _message = 'La compra fue cancelada.';
        });
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        setState(() {
          _busy = false;
          _message = purchase.error?.message ?? 'La tienda rechazó la compra.';
        });
        continue;
      }
      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        continue;
      }

      try {
        final transactionId = purchase.purchaseID?.trim() ?? '';
        if (!RegExp(r'^[0-9]{5,30}$').hasMatch(transactionId)) {
          throw StateError('Apple no proporcionó un identificador verificable de transacción.');
        }
        if (!_mapped.any((item) => item.productId == purchase.productID)) {
          throw StateError('Este producto no está asociado a un plan de BarLytics.');
        }
        final response = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
          '/api/v1/subscriptions/apple/verify',
          {'transactionId': transactionId, 'productId': purchase.productID},
          (json) => Map<String, dynamic>.from(json as Map),
        );
        if (response.data?['active'] != true) {
          throw StateError('Apple todavía no confirmó una suscripción vigente.');
        }
        // Confirmar en StoreKit solo después de comprobar la transacción real
        // y registrar la titularidad en el backend.
        if (purchase.pendingCompletePurchase) {
          await _store.completePurchase(purchase);
        }
        await _refreshEntitlement();
        if (mounted) setState(() {
          _busy = false;
          _message = 'Suscripción verificada y sincronizada con App Store.';
        });
        if (mounted) await widget.onConfirmed?.call();
      } catch (error) {
        // No desbloquear funciones ni dar por finalizada una transacción inválida.
        if (mounted) setState(() {
          _busy = false;
          _message = 'La compra no se pudo verificar: $error. '
              'Puedes volver a usar Restaurar compras después de corregir el problema.';
        });
      }
    }
  }

  Future<void> _refreshEntitlement() async {
    final sub = await ref.read(subscriptionRemoteDataSourceProvider).current();
    if (!mounted) return;
    await ref.read(authControllerProvider.notifier).updateSubscription(
      status: sub.status,
      active: sub.active,
    );
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = 'Consultando compras anteriores en Apple…';
    });
    try {
      await _store.restorePurchases();
      // Los resultados de restauración se entregan en purchaseStream.
      // La ausencia de recibos no debe bloquear indefinidamente el botón.
      if (mounted && _busy) setState(() {
        _busy = false;
        _message = 'Si Apple encuentra compras asociadas, las validaremos automáticamente. '
            'También puedes usar Sincronizar para verificar tu cuenta actual.';
      });
    } catch (error) {
      if (mounted) setState(() {
        _busy = false;
        _message = 'No fue posible restaurar compras: $error';
      });
    }
  }

  Future<void> _sync() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final response = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        '/api/v1/subscriptions/apple/sync',
        const <String, dynamic>{},
        (json) => Map<String, dynamic>.from(json as Map),
      );
      await _refreshEntitlement();
      if (mounted) setState(() => _message = response.data?['active'] == true
          ? 'Tu suscripción está activa y verificada en App Store.'
          : 'No se encontró una suscripción de Apple vigente vinculada a este negocio.');
      if (mounted) await widget.onConfirmed?.call();
    } catch (error) {
      if (mounted) setState(() => _message = 'No se pudo sincronizar: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAppleSubscriptions() async {
    await launchUrl(
      Uri.parse('https://apps.apple.com/account/subscriptions'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pagar con App Store', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text(
          'Selecciona un plan; Apple mostrará el precio y confirmará el pago en tu Apple ID. '
          'La suscripción se renueva automáticamente al precio indicado por la App Store, '
          'salvo que canceles la renovación desde tu cuenta Apple.',
        ),
        const SizedBox(height: 12),
        for (final plan in _mapped)
          if (_products[plan.productId] case final ProductDetails product)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(plan.planName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(product.description.isNotEmpty
                        ? product.description
                        : 'Suscripción auto-renovable de BarLytics'),
                    const SizedBox(height: 8),
                    Text(product.price + ' / ' + plan.periodLabel,
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _busy || !_serverReady || _blockedByMercadoPago
                          ? null : () => _buy(product),
                      icon: const Icon(Icons.apple),
                      label: const Text('Suscribirme con Apple'),
                    ),
                  ],
                ),
              ),
            ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(_message!, style: theme.textTheme.bodySmall),
          ),
        if (_busy) const LinearProgressIndicator(),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _restore,
              icon: const Icon(Icons.restore),
              label: const Text('Restaurar compras'),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _sync,
              icon: const Icon(Icons.sync),
              label: const Text('Sincronizar'),
            ),
            TextButton.icon(
              onPressed: _openAppleSubscriptions,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Gestionar en Apple'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'La renovación se cancela desde Ajustes > Apple ID > Suscripciones; '
          'el acceso continúa hasta terminar el periodo ya pagado.',
          style: TextStyle(fontSize: 11),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://www.barlytics.com.co/terminos/'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Términos de uso'),
            ),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://www.barlytics.com.co/privacidad/'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Política de privacidad'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ApplePlan {
  const _ApplePlan({
    required this.productId,
    required this.planName,
    required this.backendReady,
    required this.frequency,
    required this.frequencyType,
  });
  final String productId;
  final String planName;
  final bool backendReady;
  final int frequency;
  final String frequencyType;

  String get periodLabel {
    if (frequencyType == 'months') {
      if (frequency == 12) return 'año';
      return frequency == 1 ? 'mes' : frequency.toString() + ' meses';
    }
    if (frequencyType == 'days') {
      return frequency == 7 ? 'semana' : frequency.toString() + ' días';
    }
    return 'periodo';
  }

  factory _ApplePlan.fromJson(Map<String, dynamic> json) => _ApplePlan(
        productId: json['productId']?.toString() ?? '',
        planName: json['planName']?.toString() ?? 'Plan BarLytics',
        backendReady: json['backendReady'] == true,
        frequency: (json['frequency'] as num?)?.toInt() ?? 1,
        frequencyType: json['frequencyType']?.toString() ?? 'months',
      );
}
