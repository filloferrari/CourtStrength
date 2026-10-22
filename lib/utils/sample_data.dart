import '../models/exercise.dart';
import '../models/workout.dart';

/// Programma dimostrativo inserito una sola volta al primo avvio.
class SampleData {
  SampleData._();

  static List<Workout> build() {
    final now = DateTime.now();
    return [
      Workout(
        id: newId(),
        title: 'Esempio · Upper Body',
        subtitle: 'Strength',
        description:
            'Programma dimostrativo con due superset (A e B) e un esercizio singolo. Modificalo o eliminalo quando vuoi.',
        durationMinutes: 55,
        isSample: true,
        createdAt: now,
        updatedAt: now,
        exercises: [
          Exercise(
              id: newId(),
              category: 'A1',
              name: 'Panca piana',
              description: 'Esercizio per il petto',
              sets: 4,
              reps: '8',
              weightKg: 60,
              restSeconds: 90,
              blockId: 'A'),
          Exercise(
              id: newId(),
              category: 'A2',
              name: 'Rematore',
              description: 'Esercizio per la schiena',
              sets: 4,
              reps: '10',
              weightKg: 40,
              restSeconds: 90,
              blockId: 'A'),
          Exercise(
              id: newId(),
              category: 'B1',
              name: 'Military press',
              description: 'Spalle',
              sets: 3,
              reps: '10',
              weightKg: 30,
              restSeconds: 75,
              blockId: 'B'),
          Exercise(
              id: newId(),
              category: 'B2',
              name: 'Alzate laterali',
              description: 'Deltoidi laterali',
              sets: 3,
              reps: '12-15',
              weightKg: 8,
              restSeconds: 75,
              blockId: 'B'),
          Exercise(
              id: newId(),
              category: 'C',
              name: 'Plank',
              description: 'Core',
              sets: 3,
              reps: '30 sec',
              weightKg: 0,
              restSeconds: 45),
        ],
      ),
    ];
  }
}
