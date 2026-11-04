import 'package:barlytics_frontend/features/deportes/presentation/widgets/sports_agenda_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resumen compacto de partidos', () {
    test('limita el carrusel a cinco partidos sin alterar la lista', () {
      final full = List.generate(14,
          (i) => <String, dynamic>{'nombre': 'Partido $i'});
      final compact = sportsCompactMatches(full);
      expect(compact, hasLength(5));
      expect(compact.first['nombre'], 'Partido 0');
      expect(compact.last['nombre'], 'Partido 4');
      expect(full, hasLength(14));
    });

    test('admite día sin partidos y jornadas cortas', () {
      expect(sportsCompactMatches([]), isEmpty);
      expect(sportsCompactMatches([
        <String, dynamic>{'nombre': 'Único partido'},
      ]), hasLength(1));
    });
  });

  group('partidos de hoy en Inicio gerencial', () {
    test('utiliza fecha Colombia cuando UTC ya pasó a otro día', () {
      final today = sportsTodayBogota(now: DateTime.utc(2026, 11, 3, 2, 45));
      expect(today.year, 2026);
      expect(today.month, 11);
      expect(today.day, 2);
    });

    test('renueva fecha cuando Bogotá llega a medianoche', () {
      final before = sportsTodayBogota(now: DateTime.utc(2026, 11, 3, 4, 59));
      final after = sportsTodayBogota(now: DateTime.utc(2026, 11, 3, 5, 0));
      expect(before.day, 2);
      expect(after.day, 3);
      expect(after.difference(before).inDays, 1);
    });

    test('respeta el mismo día en Colombia durante el día', () {
      final today = sportsTodayBogota(now: DateTime.utc(2026, 11, 2, 20));
      expect(today.day, 2);
    });
  });
}
