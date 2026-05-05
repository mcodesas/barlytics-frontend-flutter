import 'package:flutter/material.dart';

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({super.key, this.message = 'No hay registros para mostrar'});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}
