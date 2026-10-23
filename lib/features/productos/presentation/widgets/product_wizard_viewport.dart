import 'package:flutter/material.dart';

/// Zona del asistente de productos dentro de AppScaffold.
///
/// Evita un Scaffold anidado: en iOS podía aparecer la barra «Siguiente /
/// Anterior» arriba, mientras el contenido del formulario quedaba fuera de
/// la zona visible. El contenido ocupa todo el espacio restante y su scroll
/// es independiente de los botones del pie.
class ProductWizardViewport extends StatelessWidget {
  const ProductWizardViewport({
    super.key,
    required this.content,
    required this.navigation,
  });

  final Widget content;
  final Widget navigation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: content),
        navigation,
      ],
    );
  }
}
