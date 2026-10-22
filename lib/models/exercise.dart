import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// Genera un identificatore univoco.
String newId() => _uuid.v4();

/// Esercizio di un programma. L'ordine è dato dalla posizione nella lista
/// del programma; il blocco/superset da [blockId] (stesso id = stesso blocco).
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.category = '',
    this.description = '',
    this.sets = 3,
    this.reps = '10',
    this.weightKg = 0,
    this.restSeconds = 60,
    this.blockId,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final int sets;

  /// Stringa libera: `8`, `10-12`, `AMRAP`, `30 sec`...
  final String reps;
  final double weightKg;
  final int restSeconds;

  /// Identificatore del blocco/superset. `null` = esercizio singolo.
  final String? blockId;

  Exercise copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    int? sets,
    String? reps,
    double? weightKg,
    int? restSeconds,
    String? blockId,
    bool clearBlock = false,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weightKg: weightKg ?? this.weightKg,
      restSeconds: restSeconds ?? this.restSeconds,
      blockId: clearBlock ? null : (blockId ?? this.blockId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'name': name,
        'description': description,
        'sets': sets,
        'reps': reps,
        'weight_kg': weightKg,
        'rest_seconds': restSeconds,
        'block_id': blockId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Exercise &&
          other.id == id &&
          other.name == name &&
          other.category == category &&
          other.description == description &&
          other.sets == sets &&
          other.reps == reps &&
          other.weightKg == weightKg &&
          other.restSeconds == restSeconds &&
          other.blockId == blockId;

  @override
  int get hashCode => Object.hash(
      id, name, category, description, sets, reps, weightKg, restSeconds, blockId);
}

/// Id dei blocchi che contengono almeno due esercizi (veri superset).
Set<String> supersetBlockIds(Iterable<Exercise> exercises) {
  final counts = <String, int>{};
  for (final e in exercises) {
    final b = e.blockId;
    if (b != null) counts[b] = (counts[b] ?? 0) + 1;
  }
  return counts.entries.where((e) => e.value > 1).map((e) => e.key).toSet();
}
