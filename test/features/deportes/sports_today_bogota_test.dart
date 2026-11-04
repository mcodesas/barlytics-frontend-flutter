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

    test('prioriza Liga BetPlay aunque tenga inicio más tarde', () {
      final matches = <Map<String, dynamic>>[
        for (var i = 0; i < 8; i++)
          {'nombre': 'Europeo $i', 'horaBogota': '2026-11-04T15:00'},
        {
          'nombre': 'Millonarios vs América de Cali',
          'liga': 'Liga BetPlay (Colombia)',
          'ligaCodigo': 'col.1',
          'horaBogota': '2026-11-04T20:30',
        },
      ];
      final compact = sportsCompactMatches(matches);
      expect(compact, hasLength(5));
      expect(compact.first['nombre'], 'Millonarios vs América de Cali');
      expect(compact.where((v) => v['nombre'] == 'Millonarios vs América de Cali'),
          hasLength(1));
      expect(matches.first['nombre'], 'Europeo 0');
    });

    test('incluye partidos colombianos al principio respetando su orden', () {
      final matches = <Map<String, dynamic>>[
        {'nombre': 'Europa A', 'liga': 'Bundesliga'},
        {'nombre': 'Cúcuta vs Santa Fe', 'ligaCodigo': 'col.1'},
        {'nombre': 'Europa B', 'liga': 'La Liga'},
        {'nombre': 'Millonarios vs América', 'liga': 'Liga BetPlay'},
      ];
      final compact = sportsCompactMatches(matches);
      expect(compact.map((m) => m['nombre']).toList(), [
        'Cúcuta vs Santa Fe',
        'Millonarios vs América',
        'Europa A',
        'Europa B',
      ]);
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
