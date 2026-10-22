import 'package:courtstrength/services/workout_timer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late FakeClock clock;
  late WorkoutTimerService timer;
  late int finished;
  late List<RestEndReason> reasons;

  setUp(() {
    clock = FakeClock();
    finished = 0;
    reasons = [];
    timer = WorkoutTimerService(clock: clock.call)
      ..onFinished = (r) {
        finished++;
        reasons.add(r);
      };
  });

  tearDown(() => timer.dispose());

  test('il tempo residuo deriva dalla scadenza, non dai tick', () {
    timer.start(90);
    expect(timer.remainingSeconds, 90);
    clock.advance(30); // "app sospesa": nessun tick ricevuto
    expect(timer.remainingSeconds, 60);
  });

  test('+15 e -15 secondi', () {
    timer.start(60);
    timer.adjust(15);
    expect(timer.remainingSeconds, 75);
    timer.adjust(-15);
    timer.adjust(-15);
    expect(timer.remainingSeconds, 45);
    expect(finished, 0);
  });

  test('a scadenza completa una sola volta e non va in negativo', () {
    timer.start(10);
    clock.advance(500); // molto oltre la scadenza
    expect(timer.remainingSeconds, 0);
    timer.checkNow();
    timer.checkNow();
    timer.checkNow();
    expect(finished, 1);
    expect(reasons.single, RestEndReason.elapsed);
    expect(timer.isRunning, isFalse);
  });

  test('skip completa una sola volta', () {
    timer.start(60);
    timer.skip();
    timer.skip();
    expect(finished, 1);
    expect(reasons.single, RestEndReason.skipped);
  });

  test('-15 s oltre il tempo residuo termina il recupero (una volta)', () {
    timer.start(10);
    timer.adjust(-15);
    timer.adjust(-15);
    expect(finished, 1);
    expect(timer.remainingSeconds, 0);
  });

  test('start sostituisce il timer precedente senza completarlo', () {
    timer.start(60);
    timer.start(30);
    expect(finished, 0);
    expect(timer.remainingSeconds, 30);
  });

  test('cancel non esegue il completamento', () {
    timer.start(60);
    timer.cancel();
    expect(finished, 0);
    expect(timer.isRunning, isFalse);
  });

  test('restore con scadenza già passata completa subito, una volta', () {
    timer.restore(clock.now.subtract(const Duration(seconds: 5)),
        const Duration(seconds: 60));
    expect(finished, 1);
    expect(timer.isRunning, isFalse);
  });

  test('restore con scadenza futura riparte dal tempo residuo', () {
    timer.restore(clock.now.add(const Duration(seconds: 40)), const Duration(seconds: 60));
    expect(timer.isRunning, isTrue);
    expect(timer.remainingSeconds, 40);
    expect(finished, 0);
  });
}
