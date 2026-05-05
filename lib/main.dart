import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap/bootstrap.dart';

/// Punto de entrada principal de BarLytics.
Future<void> main() async {
  await bootstrap();
  runApp(const ProviderScope(child: BarLyticsApp()));
}
