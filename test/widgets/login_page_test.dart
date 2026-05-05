import 'package:barlytics_frontend/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LoginPage muestra campos principales', (tester) async {
    // Arrange
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginPage())));

    // Act / Assert
    expect(find.text('BarLytics'), findsOneWidget);
    expect(find.text('Correo o identificador'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });
}
