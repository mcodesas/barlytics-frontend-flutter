import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../providers/subscription_provider.dart';

/// Compra mensual de BarLytics desde las cuentas Apple / Google.
/// Los importes y la recurrencia los muestra la tienda; el backend solo
/// habilita el plan cuando ha verificado la operación con su API oficial.
class StoreSubscriptionPanel extends ConsumerStatefulWidget {
  const StoreSubscriptionPanel({
    super.key,
    required this.planCode,
    required this.onConfirmed,
  });

  final String? planCode;
  final Future<void> Function() onConfirmed;

  static bool get availablePlatform =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS ||
                 defaultTargetPlatform == TargetPlatform.android);

  static String get provider =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'APPLE' : 'GOOGLE';

  @override
  ConsumerState<StoreSubscriptionPanel> createState() =>
      _StoreSubscriptionPanelState();
}

class _StoreSubscriptionPanelState extends ConsumerState<StoreSubscriptionPanel> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _updates;
  bool _loading = true;
  bool _busy = false;
  bool _storeAvailable = false;
  String? _message;
  String? _productId;
  ProductDetails? _product;
  final Set<String> _allowedProductIds = <String>{};
  final Set<String> _processingPurchases = <String>{};

  @override
  void initState() {
    super.initState();
    if (StoreSubscriptionPanel.availablePlatform) {
      // Es indispensable suscribirse antes de abrir StoreKit / Billing.
      _updates = _iap.purchaseStream.listen(_purchaseUpdates,
          onError: (Object error) {
            if (mounted) setState(() {
              _busy = false;
              _message = 'No se pudo consultar el estado de la tienda: $error';
            });
          });
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(covariant StoreSubscriptionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.planCode != widget.planCode) _load();
  }

  @override
  void dispose() {
    _updates?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!StoreSubscriptionPanel.availablePlatform) return;
    setState(() {
      _loading = true;
      _message = null;
      _product = null;
      _productId = null;
      _allowedProductIds.clear();
    });
    try {
      final available = await _iap.isAvailable();
      if (!available) throw StateError('La tienda no está disponible en este dispositivo.');
      final products = await ref.read(subscriptionRemoteDataSourceProvider)
          .storeProducts(StoreSubscriptionPanel.provider);
      for (final item in products) {
        final id = item['productId']?.toString();
        if (id != null && id.isNotEmpty) _allowedProductIds.add(id);
      }
      final chosen = products.where((item) =>
        item['planCode']?.toString() == widget.planCode).toList();
      if (chosen.isEmpty) {
        throw StateError('Este plan aún no tiene un producto mensual aprobado en la tienda.');
      }
      final id = chosen.first['productId']?.toString() ?? '';
      final response = await _iap.queryProductDetails(<String>{id});
      if (response.error != null) throw StateError(response.error!.message);
      final details = response.productDetails.where((item) => item.id == id).toList();
      if (details.isEmpty) {
        throw StateError('El producto mensual todavía no está publicado para esta cuenta de la tienda.');
      }
      if (!mounted) return;
      setState(() {
        _storeAvailable = true;
        _productId = id;
        _product = details.first;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _storeAvailable = false;
        _message = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _buy() async {
    final product = _product;
    if (product == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final companyToken = await ref.read(subscriptionRemoteDataSourceProvider)
          .prepareStorePurchase(StoreSubscriptionPanel.provider, product.id);
      final launched = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          // Identificador UUID opaco por empresa; Apple lo devuelve como
          // appAccountToken y Google como obfuscatedExternalAccountId.
          applicationUserName: companyToken,
        ),
      );
      if (!launched && mounted) setState(() {
        _busy = false;
        _message = 'No se pudo abrir el formulario de pago de la tienda.';
      });
    } catch (error) {
      if (mounted) setState(() {
        _busy = false;
        _message = 'No fue posible iniciar el pago: $error';
      });
    }
  }

  Future<void> _restore() async {
    if (_busy || !_storeAvailable) return;
    setState(() {
      _busy = true;
      _message = 'Consultando compras anteriores…';
    });
    try {
      await _iap.restorePurchases();
      // Restaurar publica eventos en purchaseStream asíncronamente.
      if (mounted) setState(() => _message =
          'Revisando las compras encontradas. Solo se restauran las que pertenecen a esta empresa.');
    } catch (error) {
      if (mounted) setState(() => _message = 'No se pudo restaurar: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _purchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          if (mounted) setState(() {
            _busy = true;
            _message = 'Esperando la confirmación del pago en la tienda…';
          });
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _verifyAndComplete(purchase);
          break;
        case PurchaseStatus.canceled:
          if (mounted) setState(() {
            _busy = false;
            _message = 'No se realizó ningún cobro. Puedes intentarlo nuevamente.';
          });
          break;
        case PurchaseStatus.error:
          if (mounted) setState(() {
            _busy = false;
            _message = purchase.error?.message ?? 'La tienda rechazó la compra.';
          });
          break;
      }
    }
  }

  Future<void> _verifyAndComplete(PurchaseDetails purchase) async {
    if (!_allowedProductIds.contains(purchase.productID)) return;
    final marker = '${purchase.productID}:${purchase.purchaseID ?? purchase.transactionDate ?? ''}';
    if (!_processingPurchases.add(marker)) return;
    try {
      final ref = StoreSubscriptionPanel.provider == 'APPLE'
          ? (purchase.purchaseID ?? '')
          : purchase.verificationData.serverVerificationData;
      if (ref.isEmpty) {
        throw StateError('La tienda no proporcionó una referencia verificable.');
      }
      // No aceptar el pago basándose solamente en PurchaseStatus.purchased.
      final active = await this.ref.read(subscriptionRemoteDataSourceProvider)
          .confirmStorePurchase(StoreSubscriptionPanel.provider, purchase.productID, ref);
      // El backend ya ha procesado la transacción y es seguro finalizarla.
      if (purchase.pendingCompletePurchase) await _iap.completePurchase(purchase);
      if (active) await widget.onConfirmed();
      if (mounted) setState(() {
        _busy = false;
        _message = active
            ? 'Suscripción verificada y activada para tu empresa.'
            : 'La tienda confirmó la operación, pero la suscripción aún no está activa.';
      });
    } catch (error) {
      // NO finalizar compras no verificadas. Android las reembolsa después
      // del plazo de acknowledgement; el usuario podrá restaurar/reintentar.
      if (mounted) setState(() {
        _busy = false;
        _message = 'El pago está pendiente de verificación. '
            'No repitas la compra. Usa «Restaurar compras» o contacta soporte. $error';
      });
    } finally {
      _processingPurchases.remove(marker);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!StoreSubscriptionPanel.availablePlatform) return const SizedBox.shrink();
    final apple = StoreSubscriptionPanel.provider == 'APPLE';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(apple ? Icons.apple : Icons.shop_rounded, size: 27),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(apple ? 'Suscripción mensual con App Store'
                      : 'Suscripción mensual con Google Play',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  const Text('Cobro automático y seguro con tu cuenta de la tienda.',
                    style: TextStyle(fontSize: 12)),
                ],
              )),
            ]),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(22),
                child: CircularProgressIndicator(strokeWidth: 2))),
            if (!_loading && _product != null) ...[
              Text(_product!.title, style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 5),
              Text(_product!.description,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              Text('${_product!.price} / mes',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 13),
              FilledButton.icon(
                onPressed: _busy ? null : _buy,
                icon: const Icon(Icons.lock_outline_rounded),
                label: Text(_busy ? 'Procesando pago…' : 'Suscribirme mensualmente'),
              ),
            ],
            const SizedBox(height: 9),
            OutlinedButton.icon(
              onPressed: _busy || !_storeAvailable ? null : _restore,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Restaurar compras'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 9),
              Text(_message!, style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Text('Puedes cancelar la renovación desde las suscripciones de tu '
              '${apple ? 'Apple ID' : 'cuenta de Google Play'}. '
              'El acceso se conserva hasta finalizar el periodo pagado. '
              'La suscripción se aplica a toda la empresa en BarLytics.',
              style: TextStyle(fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
            TextButton.icon(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualizar productos'),
            ),
          ],
        ),
      ),
    );
  }
}
