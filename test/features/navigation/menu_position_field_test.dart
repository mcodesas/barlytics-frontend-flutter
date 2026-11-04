import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/navigation/presentation/pages/personalizar_menu_page.dart';

void main() {
  Widget field({
    required int position,
    required int maxPosition,
    required ValueChanged<String> onDraft,
    required ValueChanged<int> onCommit,
  }) => MaterialApp(
        home: Scaffold(
          body: MenuPositionField(
            position: position,
            maxPosition: maxPosition,
            onDraftChanged: onDraft,
            onCommit: onCommit,
          ),
        ),
      );

  testWidgets('Al escribir posición 1 se aplica automáticamente',
      (tester) async {
    final moves = <int>[];
    await tester.pumpWidget(field(
      position: 8,
      maxPosition: 12,
      onDraft: (_) {},
      onCommit: moves.add,
    ));

    await tester.enterText(
        find.byKey(const ValueKey('menu-position-number')), '1');
    await tester.pump(const Duration(milliseconds: 649));
    expect(moves, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(moves, [1]);
  });

  testWidgets('Escribir 12 no mueve primero a posición 1',
      (tester) async {
    final moves = <int>[];
    await tester.pumpWidget(field(
      position: 8,
      maxPosition: 20,
      onDraft: (_) {},
      onCommit: moves.add,
    ));

    final input = find.byKey(const ValueKey('menu-position-number'));
    await tester.enterText(input, '1');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(input, '12');
    await tester.pump(const Duration(milliseconds: 649));
    expect(moves, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(moves, [12]);
  });

  testWidgets('No se aplican automáticamente valores fuera de rango',
      (tester) async {
    final moves = <int>[];
    await tester.pumpWidget(field(
      position: 4,
      maxPosition: 10,
      onDraft: (_) {},
      onCommit: moves.add,
    ));

    await tester.enterText(
        find.byKey(const ValueKey('menu-position-number')), '0');
    await tester.pump(const Duration(milliseconds: 800));
    expect(moves, isEmpty);
  });

  testWidgets('El botón de confirmación aplica inmediatamente',
      (tester) async {
    final moves = <int>[];
    await tester.pumpWidget(field(
      position: 8,
      maxPosition: 12,
      onDraft: (_) {},
      onCommit: moves.add,
    ));

    await tester.enterText(
        find.byKey(const ValueKey('menu-position-number')), '2');
    await tester.tap(find.byTooltip('Mover a posición'));
    await tester.pump();
    expect(moves, [2]);
    await tester.pump(const Duration(milliseconds: 800));
    expect(moves, [2]);
  });
}
