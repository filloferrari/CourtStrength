import 'dart:io';

import 'package:courtstrength/models/exercise.dart';
import 'package:courtstrength/models/workout_session.dart';
import 'package:courtstrength/services/workout_import_export_service.dart';
import 'package:courtstrength/services/workout_storage_service.dart';
import 'package:courtstrength/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

AppState makeState(Directory dir) => AppState(
      storage: WorkoutStorageService(dir),
      importExport: WorkoutImportExportService(),
    );

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('cs_state_'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('i programmi demo vengono inseriti una sola volta', () async {
    final a = makeState(dir);
    await a.init();
    expect(a.workouts, hasLength(1));
    expect(a.workouts.single.isSample, isTrue);

    final b = makeState(dir); // riapertura
    await b.init();
    expect(b.workouts, hasLength(1));

    await b.deleteWorkout(b.workouts.single.id);
    final c = makeState(dir);
    await c.init();
    expect(c.workouts, isEmpty); // non vengono reinseriti dopo l'eliminazione
  });

  test('crea → modifica → riordina → salva → riapri', () async {
    final a = makeState(dir);
    await a.init(seedSamples: false);
    final w = sampleWorkout();
    await a.saveWorkout(w);

    final edited = w.copyWith(
      title: 'Modificato',
      exercises: [w.exercises[2], w.exercises[0], w.exercises[1]],
    );
    await a.saveWorkout(edited);

    final b = makeState(dir);
    await b.init(seedSamples: false);
    expect(b.workouts, hasLength(1));
    expect(b.workouts.single.title, 'Modificato');
    expect(b.workouts.single.exercises.map((e) => e.id), ['b1', 'a1', 'a2']);
  });

  test('duplica programma con nuovi id e titolo univoco', () async {
    final a = makeState(dir);
    await a.init(seedSamples: false);
    await a.saveWorkout(sampleWorkout());
    final copy = (await a.duplicateWorkout('w1'))!;
    expect(copy.id, isNot('w1'));
    expect(copy.title, 'Upper Body (copia)');
    expect(copy.exercises.first.id, isNot('a1'));
    expect(a.workouts, hasLength(2));
  });

  test('esporta → reimporta senza perdere dati', () async {
    final a = makeState(dir);
    await a.init(seedSamples: false);
    final w = sampleWorkout();
    final json = a.importExport.buildExportJson([w]);
    expect(json, contains('"schemaVersion": 1'));

    final parsed = a.importExport.parseBytes(json.codeUnits);
    expect(parsed.errors, isEmpty);
    final r = parsed.workouts.single;
    expect(r.title, w.title);
    expect(r.subtitle, w.subtitle);
    expect(r.durationMinutes, w.durationMinutes);
    expect(r.exercises.length, w.exercises.length);
    for (var i = 0; i < w.exercises.length; i++) {
      expect(r.exercises[i], w.exercises[i]);
    }
  });

  test('import: nessuna sovrascrittura silenziosa, conflitti rilevati', () async {
    final a = makeState(dir);
    await a.init(seedSamples: false);
    await a.saveWorkout(sampleWorkout());

    final incoming = sampleWorkout().copyWith(id: 'altro');
    final conflict = a.findConflict(incoming);
    expect(conflict, isNotNull); // stesso titolo

    // "Importa come copia": l'esistente resta intatto.
    var n = await a.importWorkouts(
        [ImportDecision(workout: incoming, action: ImportAction.add, existing: conflict)]);
    expect(n, 1);
    expect(a.workouts, hasLength(2));
    expect(a.workouts.map((w) => w.title), contains('Upper Body (copia)'));
    expect(a.workoutById('w1')!.title, 'Upper Body');

    // "Non importare".
    n = await a.importWorkouts(
        [ImportDecision(workout: incoming, action: ImportAction.skip, existing: conflict)]);
    expect(n, 0);
    expect(a.workouts, hasLength(2));

    // "Sostituisci": mantiene l'id esistente.
    final changed = incoming.copyWith(title: 'Upper Body', description: 'Nuova');
    n = await a.importWorkouts(
        [ImportDecision(workout: changed, action: ImportAction.replace, existing: conflict)]);
    expect(n, 1);
    expect(a.workouts, hasLength(2));
    expect(a.workoutById('w1')!.description, 'Nuova');
  });

  test('applySessionToWorkout aggiorna solo carichi e serie', () async {
    final a = makeState(dir);
    await a.init(seedSamples: false);
    await a.saveWorkout(sampleWorkout());
    final s = WorkoutSession.start(sampleWorkout());
    s.exercises.first.weightKg = 70;
    s.exercises.first.totalSets = 5;
    expect(s.hasChangesFromProgram, isTrue);
    expect(await a.applySessionToWorkout(s), isTrue);
    final e = a.workoutById('w1')!.exercises.first;
    expect(e.weightKg, 70);
    expect(e.sets, 5);
    expect(e.name, 'Panca');
  });

  test('recordSession salva lo storico e azzera la sessione attiva', () async {
    final a = makeState(dir);
    await a.init(seedSamples: false);
    await a.updateActiveSnapshot({'x': 1});
    expect(a.activeSnapshot, isNotNull);
    final s = WorkoutSession.start(sampleWorkout())..endedAt = DateTime.now();
    await a.recordSession(s);
    expect(a.activeSnapshot, isNull);

    final b = makeState(dir);
    await b.init(seedSamples: false);
    expect(b.sessions, hasLength(1));
    expect(b.activeSnapshot, isNull);
  });

  test('Exercise.copyWith(clearBlock) rimuove il blocco', () {
    const e = Exercise(id: '1', name: 'x', blockId: 'A');
    expect(e.copyWith(clearBlock: true).blockId, isNull);
    expect(e.copyWith(name: 'y').blockId, 'A');
  });
}
