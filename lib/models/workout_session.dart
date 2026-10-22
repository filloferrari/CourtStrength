import 'exercise.dart';
import 'workout.dart';

/// Copia "di lavoro" di un esercizio durante una sessione: modificare carico
/// o serie qui non altera il programma originale.
class SessionExercise {
  SessionExercise({
    required this.exerciseId,
    required this.name,
    required this.category,
    required this.description,
    required this.reps,
    required this.restSeconds,
    required this.blockId,
    required this.totalSets,
    required this.originalSets,
    required this.weightKg,
    required this.originalWeightKg,
    this.completedSets = 0,
  });

  factory SessionExercise.fromExercise(Exercise e) => SessionExercise(
        exerciseId: e.id,
        name: e.name,
        category: e.category,
        description: e.description,
        reps: e.reps,
        restSeconds: e.restSeconds,
        blockId: e.blockId,
        totalSets: e.sets,
        originalSets: e.sets,
        weightKg: e.weightKg,
        originalWeightKg: e.weightKg,
      );

  factory SessionExercise.fromJson(Map<String, dynamic> j) => SessionExercise(
        exerciseId: j['exercise_id'] as String,
        name: (j['name'] as String?) ?? '',
        category: (j['category'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        reps: (j['reps'] as String?) ?? '',
        restSeconds: (j['rest_seconds'] as num?)?.toInt() ?? 0,
        blockId: j['block_id'] as String?,
        totalSets: (j['total_sets'] as num?)?.toInt() ?? 1,
        originalSets: (j['original_sets'] as num?)?.toInt() ?? 1,
        weightKg: (j['weight_kg'] as num?)?.toDouble() ?? 0,
        originalWeightKg: (j['original_weight_kg'] as num?)?.toDouble() ?? 0,
        completedSets: (j['completed_sets'] as num?)?.toInt() ?? 0,
      );

  final String exerciseId;
  final String name;
  final String category;
  final String description;
  final String reps;
  final int restSeconds;
  final String? blockId;
  int totalSets;
  final int originalSets;
  double weightKg;
  final double originalWeightKg;
  int completedSets;

  bool get isFinished => completedSets >= totalSets;

  /// Ripetizioni interpretabili come numero intero (`8`), altrimenti null.
  int? get numericReps => int.tryParse(reps.trim());

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'name': name,
        'category': category,
        'description': description,
        'reps': reps,
        'rest_seconds': restSeconds,
        'block_id': blockId,
        'total_sets': totalSets,
        'original_sets': originalSets,
        'weight_kg': weightKg,
        'original_weight_kg': originalWeightKg,
        'completed_sets': completedSets,
      };
}

/// Sessione di allenamento (in corso o conclusa).
class WorkoutSession {
  WorkoutSession({
    required this.id,
    required this.workoutId,
    required this.workoutTitle,
    required this.workoutSubtitle,
    required this.workoutDescription,
    required this.estimatedMinutes,
    required this.startedAt,
    this.endedAt,
    required this.exercises,
  });

  factory WorkoutSession.start(Workout w, {DateTime? now}) => WorkoutSession(
        id: newId(),
        workoutId: w.id,
        workoutTitle: w.title,
        workoutSubtitle: w.subtitle,
        workoutDescription: w.description,
        estimatedMinutes: w.estimatedMinutes,
        startedAt: now ?? DateTime.now(),
        exercises: [for (final e in w.exercises) SessionExercise.fromExercise(e)],
      );

  factory WorkoutSession.fromJson(Map<String, dynamic> j) => WorkoutSession(
        id: j['id'] as String,
        workoutId: (j['workout_id'] as String?) ?? '',
        workoutTitle: (j['workout_title'] as String?) ?? '',
        workoutSubtitle: (j['workout_subtitle'] as String?) ?? '',
        workoutDescription: (j['workout_description'] as String?) ?? '',
        estimatedMinutes: (j['estimated_minutes'] as num?)?.toInt() ?? 0,
        startedAt: DateTime.parse(j['started_at'] as String),
        endedAt: j['ended_at'] == null
            ? null
            : DateTime.parse(j['ended_at'] as String),
        exercises: [
          for (final e in (j['exercises'] as List<dynamic>? ?? const []))
            SessionExercise.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );

  final String id;
  final String workoutId;
  final String workoutTitle;
  final String workoutSubtitle;
  final String workoutDescription;
  final int estimatedMinutes;
  final DateTime startedAt;
  DateTime? endedAt;
  final List<SessionExercise> exercises;

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  int get totalSets => exercises.fold(0, (a, e) => a + e.totalSets);

  int get completedSets => exercises.fold(0, (a, e) => a + e.completedSets);

  int get exercisesPerformed =>
      exercises.where((e) => e.completedSets > 0).length;

  /// Volume = somma di carico × ripetizioni × serie completate, solo per gli
  /// esercizi con ripetizioni numeriche.
  double get totalVolumeKg {
    var v = 0.0;
    for (final e in exercises) {
      final r = e.numericReps;
      if (r != null) v += e.weightKg * r * e.completedSets;
    }
    return v;
  }

  /// Esercizi eseguiti esclusi dal volume perché le ripetizioni non sono numeriche.
  int get volumeExcludedCount => exercises
      .where((e) => e.completedSets > 0 && e.numericReps == null)
      .length;

  bool get hasChangesFromProgram => exercises.any(
      (e) => e.weightKg != e.originalWeightKg || e.totalSets != e.originalSets);

  Map<String, dynamic> toJson() => {
        'id': id,
        'workout_id': workoutId,
        'workout_title': workoutTitle,
        'workout_subtitle': workoutSubtitle,
        'workout_description': workoutDescription,
        'estimated_minutes': estimatedMinutes,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
}
