import 'exercise.dart';

/// Programma di allenamento salvato dall'utente.
class Workout {
  const Workout({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.description = '',
    this.durationMinutes = 0,
    this.exercises = const [],
    this.isSample = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;

  /// 0 = non impostata: si usa la stima [estimatedMinutes].
  final int durationMinutes;
  final List<Exercise> exercises;

  /// `true` per i programmi dimostrativi inseriti al primo avvio.
  final bool isSample;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get exercisesCount => exercises.length;

  int get supersetCount => supersetBlockIds(exercises).length;

  /// Durata dichiarata oppure stima (40 s per serie + recuperi).
  int get estimatedMinutes {
    if (durationMinutes > 0) return durationMinutes;
    var seconds = 0;
    for (final e in exercises) {
      seconds += e.sets * (40 + e.restSeconds);
    }
    return (seconds / 60).round();
  }

  Workout copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    int? durationMinutes,
    List<Exercise>? exercises,
    bool? isSample,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Workout(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      exercises: exercises ?? this.exercises,
      isSample: isSample ?? this.isSample,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Copia con nuovi identificatori (programma ed esercizi).
  Workout withFreshIds() => copyWith(
        id: newId(),
        exercises: [for (final e in exercises) e.copyWith(id: newId())],
      );

  Map<String, dynamic> toJson({bool forExport = false}) => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'description': description,
        'duration_minutes': durationMinutes,
        'exercises_count': exercises.length,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        if (!forExport) 'is_sample': isSample,
        if (!forExport) 'created_at': createdAt.toIso8601String(),
        if (!forExport) 'updated_at': updatedAt.toIso8601String(),
      };
}
