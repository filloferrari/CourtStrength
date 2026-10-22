import 'package:courtstrength/utils/workout_json_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const originalJson = '''
{
  "workouts": [
    {
      "title": "Upper Body",
      "subtitle": "Strength",
      "description": "Allenamento parte superiore",
      "duration_minutes": 60,
      "exercises_count": 2,
      "exercises": [
        {"category": "A1", "name": "Panca piana", "description": "Esercizio per il petto",
         "sets": 4, "reps": "8", "weight_kg": 60, "rest_seconds": 90},
        {"category": "A2", "name": "Rematore", "description": "Esercizio per la schiena",
         "sets": 4, "reps": "10", "weight_kg": 40, "rest_seconds": 90}
      ]
    }
  ]
}
''';

void main() {
  group('Formato originale', () {
    test('viene importato correttamente', () {
      final r = WorkoutJsonParser.parseDocument(originalJson);
      expect(r.fatalError, isNull);
      expect(r.errors, isEmpty);
      expect(r.workouts, hasLength(1));
      final w = r.workouts.single;
      expect(w.title, 'Upper Body');
      expect(w.durationMinutes, 60);
      expect(w.exercises, hasLength(2));
      expect(w.exercises[0].name, 'Panca piana');
      expect(w.exercises[0].reps, '8');
      expect(w.exercises[0].weightKg, 60);
      expect(w.exercises[1].restSeconds, 90);
    });

    test('le categorie A1/A2 diventano il blocco A', () {
      final w = WorkoutJsonParser.parseDocument(originalJson).workouts.single;
      expect(w.exercises[0].blockId, 'A');
      expect(w.exercises[1].blockId, 'A');
      expect(w.supersetCount, 1);
    });
  });

  group('Migrazione categorie', () {
    test('legacyBlockFromCategory', () {
      expect(WorkoutJsonParser.legacyBlockFromCategory('B2'), 'B');
      expect(WorkoutJsonParser.legacyBlockFromCategory('c10'), 'C');
      expect(WorkoutJsonParser.legacyBlockFromCategory('Riscaldamento'), isNull);
      expect(WorkoutJsonParser.legacyBlockFromCategory(''), isNull);
    });

    test('block_id esplicito ha la precedenza sulla categoria', () {
      const src = '''{"workouts":[{"title":"T","exercises":[
        {"name":"x","category":"A1","block_id":"Z"},
        {"name":"y","category":"A2","block_id":null}]}]}''';
      final w = WorkoutJsonParser.parseDocument(src).workouts.single;
      expect(w.exercises[0].blockId, 'Z');
      expect(w.exercises[1].blockId, isNull);
    });
  });

  group('File non validi', () {
    test('JSON corrotto', () {
      final r = WorkoutJsonParser.parseDocument('{"workouts": [');
      expect(r.fatalError, isNotNull);
      expect(r.isUsable, isFalse);
    });

    test('file vuoto', () {
      expect(WorkoutJsonParser.parseDocument('   ').fatalError, isNotNull);
    });

    test('radice di tipo sbagliato', () {
      expect(WorkoutJsonParser.parseDocument('42').fatalError, isNotNull);
      expect(WorkoutJsonParser.parseDocument('{"foo": 1}').fatalError, isNotNull);
    });

    test('titolo mancante', () {
      const src = '{"workouts":[{"exercises":[{"name":"x"}]}]}';
      final r = WorkoutJsonParser.parseDocument(src);
      expect(r.workouts, isEmpty);
      expect(r.errors.single, contains("'title'"));
    });

    test('tipi errati e valori fuori intervallo', () {
      const src = '''{"workouts":[{"title":"T","exercises":[
        {"name":"x","sets":"abc"},
        {"name":"y","sets":0},
        {"name":"z","weight_kg":-5},
        {"name":"w","rest_seconds":99999}]}]}''';
      final r = WorkoutJsonParser.parseDocument(src);
      expect(r.workouts, isEmpty);
      expect(r.errors, hasLength(4));
    });

    test('programma senza esercizi', () {
      final r = WorkoutJsonParser.parseDocument(
          '{"workouts":[{"title":"T","exercises":[]}]}');
      expect(r.workouts, isEmpty);
      expect(r.errors, isNotEmpty);
    });

    test('schemaVersion futura viene rifiutata', () {
      final r = WorkoutJsonParser.parseDocument(
          '{"schemaVersion": 99, "workouts": []}');
      expect(r.fatalError, contains('99'));
    });

    test('un programma valido e uno non valido: importa solo il valido', () {
      const src = '''{"workouts":[
        {"title":"Ok","exercises":[{"name":"a"}]},
        {"title":"","exercises":[{"name":"b"}]}]}''';
      final r = WorkoutJsonParser.parseDocument(src);
      expect(r.workouts, hasLength(1));
      expect(r.errors, hasLength(1));
      expect(r.isUsable, isTrue);
    });
  });

  group('Varianti di formato', () {
    test('lista di programmi e programma singolo', () {
      const list = '[{"title":"A","exercises":[{"name":"x"}]}]';
      const single = '{"title":"B","exercises":[{"name":"x"}]}';
      expect(WorkoutJsonParser.parseDocument(list).workouts.single.title, 'A');
      expect(WorkoutJsonParser.parseDocument(single).workouts.single.title, 'B');
    });

    test('numeri come testo, virgola decimale, reps numeriche', () {
      const src = '''{"workouts":[{"title":"T","duration_minutes":"45","exercises":[
        {"name":"x","sets":"4","weight_kg":"62,5","reps":12,"rest_seconds":"90"}]}]}''';
      final w = WorkoutJsonParser.parseDocument(src).workouts.single;
      expect(w.durationMinutes, 45);
      final e = w.exercises.single;
      expect(e.sets, 4);
      expect(e.weightKg, 62.5);
      expect(e.reps, '12');
      expect(e.restSeconds, 90);
    });

    test('valori di default quando i campi opzionali mancano', () {
      final e = WorkoutJsonParser.parseDocument(
              '{"workouts":[{"title":"T","exercises":[{"name":"x"}]}]}')
          .workouts
          .single
          .exercises
          .single;
      expect(e.sets, 3);
      expect(e.reps, '10');
      expect(e.weightKg, 0);
      expect(e.restSeconds, 60);
    });
  });
}
