import 'dart:convert';

import '../models/exercise.dart';
import '../models/workout.dart';

/// Risultato del parsing di un documento JSON di programmi.
class ImportParseResult {
  const ImportParseResult({
    this.workouts = const [],
    this.errors = const [],
    this.fatalError,
    this.schemaVersion,
  });

  factory ImportParseResult.fatal(String message) =>
      ImportParseResult(fatalError: message);

  /// Programmi validi.
  final List<Workout> workouts;

  /// Errori sui singoli programmi (quei programmi sono stati scartati).
  final List<String> errors;

  /// Errore che invalida l'intero file.
  final String? fatalError;
  final int? schemaVersion;

  bool get isUsable => fatalError == null && workouts.isNotEmpty;
}

/// Parser tollerante ma con validazione esplicita. Accetta:
/// - `{ "schemaVersion": 1, "workouts": [ ... ] }` (formato attuale)
/// - `{ "workouts": [ ... ] }` (formato del prototipo, senza versione)
/// - una lista di programmi
/// - un singolo programma (oggetto con `exercises`)
class WorkoutJsonParser {
  WorkoutJsonParser._();

  static const int currentSchemaVersion = 1;

  static final RegExp _legacyCategory = RegExp(r'^([A-Za-z])\s*\d+$');

  /// Regola di migrazione: `A1`, `A2` -> blocco `A`. Categorie diverse
  /// (es. "Riscaldamento") non generano blocchi.
  static String? legacyBlockFromCategory(String category) {
    final m = _legacyCategory.firstMatch(category.trim());
    return m?.group(1)!.toUpperCase();
  }

  static ImportParseResult parseDocument(String source) {
    if (source.trim().isEmpty) {
      return ImportParseResult.fatal('Il file è vuoto.');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      return ImportParseResult.fatal(
          'Il file non contiene JSON valido (${e.message}).');
    }

    int? schema;
    final List<dynamic> items;
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('schemaVersion')) {
        final v = _toInt(decoded['schemaVersion']);
        if (v == null || v < 1) {
          return ImportParseResult.fatal("Il campo 'schemaVersion' non è valido.");
        }
        if (v > currentSchemaVersion) {
          return ImportParseResult.fatal(
              'Il file usa lo schema versione $v, più recente di quello '
              'supportato ($currentSchemaVersion). Aggiorna l\'app.');
        }
        schema = v;
      }
      if (decoded.containsKey('workouts')) {
        final w = decoded['workouts'];
        if (w is! List) {
          return ImportParseResult.fatal("Il campo 'workouts' deve essere una lista.");
        }
        items = w;
      } else if (decoded.containsKey('exercises')) {
        items = [decoded];
      } else {
        return ImportParseResult.fatal(
            "Formato non riconosciuto: manca il campo 'workouts'.");
      }
    } else if (decoded is List) {
      items = decoded;
    } else {
      return ImportParseResult.fatal(
          'Formato non riconosciuto: la radice deve essere un oggetto o una lista.');
    }

    if (items.isEmpty) {
      return ImportParseResult.fatal('Il file non contiene programmi.');
    }

    final workouts = <Workout>[];
    final errors = <String>[];
    for (var i = 0; i < items.length; i++) {
      final label = 'Programma ${i + 1}';
      final item = items[i];
      if (item is! Map) {
        errors.add('$label: non è un oggetto JSON.');
        continue;
      }
      final w = parseWorkout(Map<String, dynamic>.from(item), label, errors);
      if (w != null) workouts.add(w);
    }
    return ImportParseResult(
        workouts: workouts, errors: errors, schemaVersion: schema);
  }

  /// Restituisce `null` (aggiungendo messaggi a [errors]) se il programma
  /// non è valido.
  static Workout? parseWorkout(
      Map<String, dynamic> m, String label, List<String> errors) {
    final start = errors.length;
    final title = _string(m, 'title', label, errors, required: true);
    final subtitle = _string(m, 'subtitle', label, errors);
    final description = _string(m, 'description', label, errors);

    var duration = 0;
    if (m['duration_minutes'] != null) {
      final d = _toInt(m['duration_minutes']);
      if (d == null || d < 0 || d > 1440) {
        errors.add("$label: 'duration_minutes' deve essere un intero tra 0 e 1440.");
      } else {
        duration = d;
      }
    }

    final exercises = <Exercise>[];
    final rawEx = m['exercises'];
    if (rawEx is! List) {
      errors.add("$label: manca la lista 'exercises'.");
    } else if (rawEx.isEmpty) {
      errors.add('$label: il programma non contiene esercizi.');
    } else {
      for (var i = 0; i < rawEx.length; i++) {
        final ex = _parseExercise(rawEx[i], '$label, esercizio ${i + 1}', errors);
        if (ex != null) exercises.add(ex);
      }
    }

    if (errors.length > start) return null;

    final now = DateTime.now();
    return Workout(
      id: _id(m['id']),
      title: title,
      subtitle: subtitle,
      description: description,
      durationMinutes: duration,
      exercises: exercises,
      isSample: m['is_sample'] == true,
      createdAt: _date(m['created_at']) ?? now,
      updatedAt: _date(m['updated_at']) ?? now,
    );
  }

  static Exercise? _parseExercise(Object? raw, String label, List<String> errors) {
    if (raw is! Map) {
      errors.add('$label: non è un oggetto JSON.');
      return null;
    }
    final m = Map<String, dynamic>.from(raw);
    final start = errors.length;

    final name = _string(m, 'name', label, errors, required: true);
    final category = _string(m, 'category', label, errors);
    final description = _string(m, 'description', label, errors);

    var sets = 3;
    if (m['sets'] != null) {
      final v = _toInt(m['sets']);
      if (v == null || v < 1 || v > 99) {
        errors.add("$label: 'sets' deve essere un intero tra 1 e 99.");
      } else {
        sets = v;
      }
    }

    var reps = '10';
    final r = m['reps'];
    if (r != null) {
      if (r is String) {
        if (r.trim().isNotEmpty) reps = r.trim();
      } else if (r is num) {
        reps = r == r.roundToDouble() ? r.toInt().toString() : r.toString();
      } else {
        errors.add("$label: 'reps' deve essere testo o numero.");
      }
    }

    var weight = 0.0;
    if (m['weight_kg'] != null) {
      final v = _toDouble(m['weight_kg']);
      if (v == null || v < 0 || v > 2000) {
        errors.add("$label: 'weight_kg' deve essere un numero tra 0 e 2000.");
      } else {
        weight = (v * 100).round() / 100;
      }
    }

    var rest = 60;
    if (m['rest_seconds'] != null) {
      final v = _toInt(m['rest_seconds']);
      if (v == null || v < 0 || v > 3600) {
        errors.add("$label: 'rest_seconds' deve essere un intero tra 0 e 3600.");
      } else {
        rest = v;
      }
    }

    String? blockId;
    if (m.containsKey('block_id')) {
      final b = m['block_id'];
      if (b is String) {
        if (b.trim().isNotEmpty) blockId = b.trim();
      } else if (b != null) {
        errors.add("$label: 'block_id' deve essere testo.");
      }
    } else {
      blockId = legacyBlockFromCategory(category);
    }

    if (errors.length > start) return null;

    return Exercise(
      id: _id(m['id']),
      name: name,
      category: category,
      description: description,
      sets: sets,
      reps: reps,
      weightKg: weight,
      restSeconds: rest,
      blockId: blockId,
    );
  }

  static String _id(Object? v) =>
      (v is String && v.trim().isNotEmpty) ? v.trim() : newId();

  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

  static String _string(
    Map<String, dynamic> m,
    String key,
    String label,
    List<String> errors, {
    bool required = false,
  }) {
    final v = m[key];
    if (v == null) {
      if (required) errors.add("$label: il campo '$key' è obbligatorio.");
      return '';
    }
    String s;
    if (v is String) {
      s = v.trim();
    } else if (v is num || v is bool) {
      s = v.toString();
    } else {
      errors.add("$label: il campo '$key' deve essere testo.");
      return '';
    }
    if (required && s.isEmpty) {
      errors.add("$label: il campo '$key' è obbligatorio.");
    }
    return s;
  }

  static int? _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v == v.roundToDouble() ? v.toInt() : null;
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static double? _toDouble(Object? v) {
    double? d;
    if (v is num) {
      d = v.toDouble();
    } else if (v is String) {
      d = double.tryParse(v.trim().replaceAll(',', '.'));
    }
    if (d == null || d.isNaN || d.isInfinite) return null;
    return d;
  }
}
