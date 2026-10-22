import 'package:courtstrength/models/exercise.dart';
import 'package:courtstrength/models/workout.dart';

/// Orologio controllabile per i test.
class FakeClock {
  DateTime now = DateTime(2026, 1, 1, 10, 0, 0);
  DateTime call() => now;
  void advance(int seconds) => now = now.add(Duration(seconds: seconds));
}

Workout sampleWorkout({String title = 'Upper Body'}) {
  final t = DateTime(2026, 1, 1);
  return Workout(
    id: 'w1',
    title: title,
    subtitle: 'Strength',
    description: 'Test',
    durationMinutes: 60,
    createdAt: t,
    updatedAt: t,
    exercises: const [
      Exercise(
          id: 'a1', category: 'A1', name: 'Panca', sets: 3, reps: '8',
          weightKg: 60, restSeconds: 90, blockId: 'A'),
      Exercise(
          id: 'a2', category: 'A2', name: 'Rematore', sets: 3, reps: '10',
          weightKg: 40, restSeconds: 60, blockId: 'A'),
      Exercise(
          id: 'b1', category: 'B1', name: 'Squat', sets: 2, reps: '10-12',
          weightKg: 80, restSeconds: 45),
    ],
  );
}
