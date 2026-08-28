import 'package:flutter/material.dart';

/// Payment Brick oficial para suscripción recurrente: la implementación embebida vive en Flutter Web.
class MercadoPagoRecurringBrick extends StatelessWidget {
  const MercadoPagoRecurringBrick({
    super.key,
    required this.publicKey,
    required this.amount,
    required this.payerEmail,
    required this.apiBaseUrl,
    required this.authToken,
    required this.returnUrl,
  });

  final String publicKey;
  final double amount;
  final String payerEmail;
  final String apiBaseUrl;
  final String authToken;
  final String returnUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: const Text(
        'El Payment Brick de suscripción de Mercado Pago se muestra en la versión web de BarLytics.',
        textAlign: TextAlign.center,
      ),
    );
  }
}
