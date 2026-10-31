import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Viewport acotado para el editor de productos, incluso cuando el padre
/// coloca el asistente dentro de un scroll con altura no acotada.
///
/// El formulario ocupa el espacio libre y tiene su propio desplazamiento,
/// mientras que los botones se mantienen visibles al pie. En iOS, un Column
/// con Expanded dentro de un antecesor sin altura podía colapsar el formulario
/// y dejar solo «Siguiente / Anterior» al principio de la pantalla.
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.sizeOf(context);
        final safePadding = MediaQuery.paddingOf(context);
        final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
        final availableHeight = constraints.hasBoundedHeight &&
                constraints.maxHeight.isFinite &&
                constraints.maxHeight > 0
            ? constraints.maxHeight
            : math.max(
                330.0,
                screen.height - safePadding.vertical - keyboardHeight - 125.0,
              );

        return SizedBox(
          width: double.infinity,
          height: availableHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SizedBox.expand(child: content),
              ),
              navigation,
            ],
          ),
        );
      },
    );
  }
}


/// Acciones del asistente como tarjeta compacta encima del menú del sistema.
///
/// Mantiene los botones accesibles sin dibujar otra franja de ancho completo
/// sobre la barra de navegación de BarLytics.
class ProductWizardFooter extends StatelessWidget {
  const ProductWizardFooter({
    super.key,
    required this.child,
    required this.surfaceColor,
    required this.borderColor,
    required this.shadowColor,
  });

  final Widget child;
  final Color surfaceColor;
  final Color borderColor;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: DecoratedBox(
              key: const Key('product-wizard-footer-card'),
              decoration: BoxDecoration(
                color: surfaceColor.withOpacity(0.98),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
