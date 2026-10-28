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
