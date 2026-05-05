import 'package:flutter/material.dart';

import '../app.dart';

/// Inicializa dependencias globales antes de levantar la aplicación.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
}
