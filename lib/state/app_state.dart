import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../services/workout_import_export_service.dart';
import '../services/workout_storage_service.dart';
import '../utils/sample_data.dart';

enum ImportAction { add, replace, skip }

/// Scelta dell'utente per un programma in fase di importazione.
class ImportDecision {
  ImportDecision({required this.workout, required this.action, this.existing});

  final Workout workout;
  ImportAction action;

  /// Programma già presente con stesso id o stesso titolo (se esiste).
  final Workout? existing;
}

/// Stato applicativo (Provider/ChangeNotifier): l'unico punto che parla con
/// i servizi di persistenza; i widget non accedono mai direttamente ai file.
class AppState extends ChangeNotifier {
  AppState({required this.storage, required this.importExport});

  final WorkoutStorageService storage;
  final WorkoutImportExportService importExport;

  List<Workout> _workouts = const [];
  List<WorkoutSession> _sessions = const [];
  Map<String, dynamic>? _activeSnapshot;
  bool _loading = true;
  String? _loadError;

  List<Workout> get workouts => List.unmodifiable(_workouts);
  List<WorkoutSession> get sessions => List.unmodifiable(_sessions);
  Map<String, dynamic>? get activeSnapshot => _activeSnapshot;
  bool get loading => _loading;
  String? get loadError => _loadError;

  Workout? workoutById(String id) {
    for (final w in _workouts) {
      if (w.id == id) return w;
    }
    return null;
  }

  Future<void> init({bool seedSamples = true}) async {
    _loading = true;
    _loadError = null;
    try {
      final lib = await storage.loadLibrary();
      var list = lib.workouts;
      if (!lib.seeded && seedSamples) {
        list = [...list, ...SampleData.build()];
        await storage.saveLibrary(list, seeded: true);
      }
      _workouts = list;
      _sessions = await storage.loadSessions();
      _activeSnapshot = await storage.loadActiveSession();
    } catch (e) {
      _loadError = 'Impossibile caricare i dati: $e';
    }
    _loading = false;
    notifyListeners();
  }

  // ---- Programmi ----------------------------------------------------------

  Future<void> _commit(List<Workout> next) async {
    await storage.saveLibrary(next, seeded: true);
    _workouts = next;
    notifyListeners();
  }

  /// Crea o aggiorna un programma.
  Future<void> saveWorkout(Workout w) async {
    final next = List<Workout>.of(_workouts);
    final idx = next.indexWhere((x) => x.id == w.id);
    final updated = w.copyWith(updatedAt: DateTime.now());
    if (idx >= 0) {
      next[idx] = updated;
    } else {
      next.insert(0, updated);
    }
    await _commit(next);
  }

  Future<void> deleteWorkout(String id) =>
      _commit(_workouts.where((w) => w.id != id).toList());

  Future<Workout?> duplicateWorkout(String id) async {
    final src = workoutById(id);
    if (src == null) return null;
    final now = DateTime.now();
    final copy = src.withFreshIds().copyWith(
          title: _uniqueTitle('${src.title} (copia)', _workouts),
          isSample: false,
          createdAt: now,
          updatedAt: now,
        );
    await _commit([copy, ..._workouts]);
    return copy;
  }

  // ---- Importazione ---------------------------------------------------------

  Workout? findConflict(Workout incoming) {
    final t = incoming.title.trim().toLowerCase();
    for (final w in _workouts) {
      if (w.id == incoming.id || w.title.trim().toLowerCase() == t) return w;
    }
    return null;
  }

  /// Applica le scelte dell'utente. Nessuna sovrascrittura silenziosa:
  /// `replace` avviene solo se scelto esplicitamente. Tutto o niente.
  Future<int> importWorkouts(List<ImportDecision> decisions) async {
    final next = List<Workout>.of(_workouts);
    final now = DateTime.now();
    var count = 0;
    for (final d in decisions) {
      if (d.action == ImportAction.skip) continue;
      final fresh = d.workout.withFreshIds();
      final existing = d.existing;
      if (d.action == ImportAction.replace && existing != null) {
        final idx = next.indexWhere((w) => w.id == existing.id);
        if (idx >= 0) {
          next[idx] = fresh.copyWith(
            id: existing.id,
            createdAt: existing.createdAt,
            updatedAt: now,
            isSample: false,
          );
          count++;
          continue;
        }
      }
      next.insert(
        0,
        fresh.copyWith(
          title: _uniqueTitle(fresh.title, next),
          createdAt: now,
          updatedAt: now,
          isSample: false,
        ),
      );
      count++;
    }
    if (count > 0) await _commit(next);
    return count;
  }

  static String _uniqueTitle(String title, List<Workout> existing) {
    bool taken(String t) =>
        existing.any((w) => w.title.trim().toLowerCase() == t.trim().toLowerCase());
    if (!taken(title)) return title;
    final base = title.endsWith(' (copia)')
        ? title.substring(0, title.length - ' (copia)'.length)
        : title;
    var candidate = '$base (copia)';
    var n = 2;
    while (taken(candidate)) {
      candidate = '$base (copia $n)';
      n++;
    }
    return candidate;
  }

  // ---- Sessioni -----------------------------------------------------------

  Future<void> updateActiveSnapshot(Map<String, dynamic>? snap) async {
    final hadSnapshot = _activeSnapshot != null;
    _activeSnapshot = snap;
    if (hadSnapshot != (snap != null)) notifyListeners();
    try {
      await storage.saveActiveSession(snap);
    } catch (_) {
      // Il salvataggio della sessione attiva è best-effort.
    }
  }

  Future<void> recordSession(WorkoutSession s) async {
    final next = [s, ..._sessions];
    if (next.length > 500) next.removeRange(500, next.length);
    await storage.saveSessions(next);
    _sessions = next;
    _activeSnapshot = null;
    try {
      await storage.saveActiveSession(null);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    final next = _sessions.where((s) => s.id != id).toList();
    await storage.saveSessions(next);
    _sessions = next;
    notifyListeners();
  }

  /// Salva nel programma i carichi/serie usati nella sessione (scelta esplicita).
  Future<bool> applySessionToWorkout(WorkoutSession s) async {
    final w = workoutById(s.workoutId);
    if (w == null) return false;
    final byId = {for (final e in s.exercises) e.exerciseId: e};
    final updated = [
      for (final e in w.exercises) _applyTo(e, byId[e.id]),
    ];
    await saveWorkout(w.copyWith(exercises: updated, isSample: false));
    return true;
  }

  static Exercise _applyTo(Exercise e, SessionExercise? s) {
    if (s == null) return e;
    return e.copyWith(weightKg: s.weightKg, sets: s.totalSets);
  }
}
