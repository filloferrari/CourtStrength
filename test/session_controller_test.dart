import 'dart:convert';

import 'package:courtstrength/models/workout_session.dart';
import 'package:courtstrength/services/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late FakeClock clock;
  late SessionController c;

  SessionExercise ex(String id) => c.byId(id)!;

  setUp(() {
    clock = FakeClock();
    c = SessionController.start(sampleWorkout(), clock: clock.call);
  });

  tearDown(() => c.dispose());

  group('Esercizio singolo', () {
    test('la serie viene registrata alla fine del recupero (skip), una sola volta', () {
      c.advance(ex('b1'));
      expect(c.timer.isRunning, isTrue);
      expect(c.timer.remainingSeconds, 45);
      expect(ex('b1').completedSets, 0);

      c.skipRest();
      expect(ex('b1').completedSets, 1);
      expect(c.timer.isRunning, isFalse);

      c.skipRest(); // evento ripetuto
      c.timer.checkNow();
      expect(ex('b1').completedSets, 1);
    });

    test('fine naturale del timer registra la serie una sola volta', () {
      c.advance(ex('b1'));
      clock.advance(45);
      c.timer.checkNow();
      c.timer.checkNow();
      expect(ex('b1').completedSets, 1);
    });

    test('doppio tocco durante il recupero viene ignorato', () {
      c.advance(ex('b1'));
      c.advance(ex('b1'));
      c.advance(ex('b1'));
      c.skipRest();
      expect(ex('b1').completedSets, 1);
    });

    test('non si superano le serie previste', () {
      for (var i = 0; i < 5; i++) {
        c.advance(ex('b1'));
        c.skipRest();
      }
      expect(ex('b1').completedSets, 2);
      expect(ex('b1').isFinished, isTrue);
      c.advance(ex('b1'));
      expect(c.timer.isRunning, isFalse);
      expect(ex('b1').completedSets, 2);
    });

    test('recupero 0: la serie si registra subito', () {
      final w = sampleWorkout();
      final zero = w.copyWith(
          exercises: [w.exercises[2].copyWith(restSeconds: 0)]);
      final c2 = SessionController.start(zero, clock: clock.call);
      addTearDown(c2.dispose);
      c2.advance(c2.byId('b1')!);
      expect(c2.timer.isRunning, isFalse);
      expect(c2.byId('b1')!.completedSets, 1);
    });
  });

  group('Superset', () {
    test('esercizio non finale: nessun timer, solo avanzamento', () {
      c.advance(ex('a1'));
      expect(c.timer.isRunning, isFalse);
      expect(c.isRoundDone(ex('a1')), isTrue);
      expect(ex('a1').completedSets, 0);
      expect(c.isRestTrigger(ex('a1')), isFalse);
      expect(c.isRestTrigger(ex('a2')), isTrue);
    });

    test('ultimo del blocco avvia il recupero e a fine timer entrambi +1', () {
      c.advance(ex('a1'));
      c.advance(ex('a2'));
      expect(c.timer.isRunning, isTrue);
      expect(c.timer.remainingSeconds, 90); // massimo fra i recuperi del blocco
      expect(c.restLabel, 'A1 + A2');
      clock.advance(90);
      c.timer.checkNow();
      expect(ex('a1').completedSets, 1);
      expect(ex('a2').completedSets, 1);
      expect(c.isRoundDone(ex('a1')), isFalse);
    });

    test('i blocchi diversi non vengono toccati', () {
      c.advance(ex('a1'));
      c.advance(ex('a2'));
      c.skipRest();
      expect(ex('b1').completedSets, 0);
    });

    test('skip nel superset registra una sola volta per entrambi', () {
      c.advance(ex('a1'));
      c.advance(ex('a2'));
      c.skipRest();
      c.skipRest();
      expect(ex('a1').completedSets, 1);
      expect(ex('a2').completedSets, 1);
    });

    test('toccare di nuovo un esercizio "fatto" annulla il passaggio', () {
      c.advance(ex('a1'));
      expect(c.isRoundDone(ex('a1')), isTrue);
      c.advance(ex('a1'));
      expect(c.isRoundDone(ex('a1')), isFalse);
    });

    test('serie totali diverse: chi ha finito non supera il totale', () {
      c.adjustSets(ex('a1'), -2); // a1: 1 serie totale, a2: 3
      c.advance(ex('a1'));
      c.advance(ex('a2'));
      c.skipRest();
      expect(ex('a1').completedSets, 1);
      expect(ex('a1').isFinished, isTrue);
      expect(ex('a2').completedSets, 1);

      // Ora a1 è finito: a2 diventa da solo il trigger del blocco.
      expect(c.isRestTrigger(ex('a2')), isTrue);
      c.advance(ex('a2'));
      c.skipRest();
      expect(ex('a1').completedSets, 1);
      expect(ex('a2').completedSets, 2);
    });
  });

  group('Più recuperi', () {
    test('avviare un nuovo recupero chiude il precedente una sola volta', () {
      c.advance(ex('b1')); // rest attivo per b1
      c.advance(ex('a1'));
      c.advance(ex('a2')); // nuovo rest: b1 viene registrato ora
      expect(ex('b1').completedSets, 1);
      expect(c.timer.isRunning, isTrue);
      expect(c.restLabel, 'A1 + A2');

      c.skipRest();
      expect(ex('a1').completedSets, 1);
      expect(ex('a2').completedSets, 1);
      expect(ex('b1').completedSets, 1); // nessun doppio incremento
    });

    test('-15/+15 si riflettono sul timer attivo', () {
      c.advance(ex('b1'));
      c.adjustRest(15);
      expect(c.timer.remainingSeconds, 60);
      c.adjustRest(-15);
      c.adjustRest(-15);
      expect(c.timer.remainingSeconds, 30);
    });
  });

  group('Carico e serie', () {
    test('il carico non scende sotto zero', () {
      final e = ex('a1')..weightKg = 1;
      c.adjustWeight(e, -2.5);
      expect(e.weightKg, 0);
      c.adjustWeight(e, -2.5);
      expect(e.weightKg, 0);
    });

    test('incrementi da 2,5 kg senza errori di arrotondamento', () {
      final e = ex('a1');
      c.adjustWeight(e, 2.5);
      expect(e.weightKg, 62.5);
      e.weightKg = 10.1;
      c.adjustWeight(e, 2.5);
      expect(e.weightKg, closeTo(12.6, 1e-9));
      c.adjustWeight(e, -2.5);
      expect(e.weightKg, closeTo(10.1, 1e-9));
    });

    test('le serie totali restano tra 1 e 99 e non sotto quelle completate', () {
      final e = ex('b1');
      c.adjustSets(e, -10);
      expect(e.totalSets, 1);
      c.adjustSets(e, 500);
      expect(e.totalSets, 99);
    });

    test('la sessione non modifica il programma originale', () {
      final original = sampleWorkout();
      final c2 = SessionController.start(original, clock: clock.call);
      addTearDown(c2.dispose);
      c2.adjustWeight(c2.byId('a1')!, 10);
      expect(c2.byId('a1')!.weightKg, 70);
      expect(original.exercises.first.weightKg, 60);
    });
  });

  group('Conclusione e ripristino', () {
    test('finish registra la serie in attesa e ferma il timer', () {
      c.advance(ex('b1'));
      final s = c.finish();
      expect(ex('b1').completedSets, 1);
      expect(c.timer.isRunning, isFalse);
      expect(s.endedAt, isNotNull);
    });

    test('snapshot: ripristino con recupero già scaduto registra la serie', () {
      c.advance(ex('b1'));
      final snap = jsonDecode(jsonEncode(c.toSnapshot())) as Map<String, dynamic>;
      clock.advance(600); // l'app è rimasta chiusa a lungo
      final r = SessionController.restore(snap, clock: clock.call);
      addTearDown(r.dispose);
      expect(r.byId('b1')!.completedSets, 1);
      expect(r.timer.isRunning, isFalse);
    });

    test('snapshot: ripristino con recupero ancora attivo riparte dal residuo', () {
      c.advance(ex('b1'));
      final snap = jsonDecode(jsonEncode(c.toSnapshot())) as Map<String, dynamic>;
      clock.advance(15);
      final r = SessionController.restore(snap, clock: clock.call);
      addTearDown(r.dispose);
      expect(r.timer.isRunning, isTrue);
      expect(r.timer.remainingSeconds, 30);
      expect(r.byId('b1')!.completedSets, 0);
      r.skipRest();
      expect(r.byId('b1')!.completedSets, 1);
    });

    test('volume: solo ripetizioni numeriche', () {
      ex('a1').completedSets = 3; // 60 kg x 8 x 3 = 1440
      ex('b1').completedSets = 2; // reps "10-12": esclusa
      final s = c.session;
      expect(s.totalVolumeKg, 1440);
      expect(s.volumeExcludedCount, 1);
      expect(s.completedSets, 5);
      expect(s.exercisesPerformed, 2);
    });
  });
}
