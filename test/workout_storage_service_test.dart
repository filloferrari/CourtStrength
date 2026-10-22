import 'dart:io';

import 'package:courtstrength/models/workout_session.dart';
import 'package:courtstrength/services/workout_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late Directory dir;
  late WorkoutStorageService storage;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cs_storage_');
    storage = WorkoutStorageService(dir);
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('directory vuota: nessun programma, non ancora inizializzata', () async {
    final lib = await storage.loadLibrary();
    expect(lib.workouts, isEmpty);
    expect(lib.seeded, isFalse);
  });

  test('salva e ricarica i programmi (persistenza)', () async {
    final w = sampleWorkout();
    await storage.saveLibrary([w], seeded: true);
    final lib = await WorkoutStorageService(dir).loadLibrary(); // "riapertura"
    expect(lib.seeded, isTrue);
    expect(lib.workouts, hasLength(1));
    final r = lib.workouts.single;
    expect(r.id, w.id);
    expect(r.exercises.map((e) => e.name), ['Panca', 'Rematore', 'Squat']);
    expect(r.exercises.map((e) => e.blockId), ['A', 'A', null]);
    expect(r.exercises[0].weightKg, 60);
  });

  test('se il file principale è corrotto si usa il backup', () async {
    await storage.saveLibrary([sampleWorkout(title: 'V1')], seeded: true);
    await storage.saveLibrary(
        [sampleWorkout(title: 'V1'), sampleWorkout(title: 'V2')], seeded: true);
    File('${dir.path}/workouts.json').writeAsStringSync('{ corrotto');
    final lib = await storage.loadLibrary();
    expect(lib.workouts, hasLength(1)); // contenuto del backup (versione precedente)
    expect(lib.workouts.single.title, 'V1');
  });

  test('storico sessioni: salvataggio e lettura', () async {
    final s = WorkoutSession.start(sampleWorkout());
    s.exercises.first.completedSets = 2;
    s.endedAt = DateTime.now();
    await storage.saveSessions([s]);
    final loaded = await storage.loadSessions();
    expect(loaded, hasLength(1));
    expect(loaded.single.exercises.first.completedSets, 2);
    expect(loaded.single.workoutTitle, 'Upper Body');
  });

  test('sessione attiva: salva e cancella', () async {
    await storage.saveActiveSession({'a': 1});
    expect((await storage.loadActiveSession())!['a'], 1);
    await storage.saveActiveSession(null);
    expect(await storage.loadActiveSession(), isNull);
  });

  test('scritture concorrenti vengono serializzate', () async {
    await Future.wait([
      for (var i = 0; i < 10; i++)
        storage.saveLibrary([sampleWorkout(title: 'T$i')], seeded: true),
    ]);
    final lib = await storage.loadLibrary();
    expect(lib.workouts.single.title, 'T9');
  });
}
