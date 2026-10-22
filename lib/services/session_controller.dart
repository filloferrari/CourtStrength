import 'package:flutter/foundation.dart';

import '../models/workout.dart';
import '../models/workout_session.dart';
import 'workout_timer_service.dart';

/// Logica di una sessione di allenamento (serie, superset, recuperi).
///
/// FLUSSO (documentato anche nel README):
/// - Esercizio singolo: «SERIE FATTA» avvia il recupero; la serie viene
///   registrata **una sola volta** quando il recupero termina o viene saltato.
/// - Superset (stesso `blockId`): negli esercizi non finali «FATTO» passa al
///   successivo senza pausa; sull'ultimo esercizio ancora attivo del blocco
///   «SERIE FATTA» avvia il recupero (il maggiore fra quelli del blocco) e a
///   fine recupero tutti gli esercizi **non conclusi del blocco** guadagnano
///   una serie.
/// - Le serie non superano mai il totale previsto (si può aumentare il totale
///   solo esplicitamente con +/−).
/// - Avviare un nuovo recupero mentre uno è attivo chiude prima quello
///   precedente (registrandone la serie una sola volta).
class SessionController extends ChangeNotifier {
  SessionController({
    required this.session,
    WorkoutTimerService? timer,
    this.onPersist,
    Clock? clock,
  })  : timer = timer ?? WorkoutTimerService(clock: clock),
        _clock = clock ?? DateTime.now {
    this.timer.onFinished = _onRestFinished;
  }

  factory SessionController.start(
    Workout workout, {
    WorkoutTimerService? timer,
    void Function(Map<String, dynamic>? snapshot)? onPersist,
    Clock? clock,
  }) {
    final now = (clock ?? DateTime.now)();
    return SessionController(
      session: WorkoutSession.start(workout, now: now),
      timer: timer,
      onPersist: onPersist,
      clock: clock,
    );
  }

  /// Ricostruisce una sessione interrotta da uno snapshot salvato.
  factory SessionController.restore(
    Map<String, dynamic> snapshot, {
    WorkoutTimerService? timer,
    void Function(Map<String, dynamic>? snapshot)? onPersist,
    Clock? clock,
  }) {
    final c = SessionController(
      session: WorkoutSession.fromJson(
          Map<String, dynamic>.from(snapshot['session'] as Map)),
      timer: timer,
      onPersist: onPersist,
      clock: clock,
    );
    c._applySnapshot(snapshot);
    return c;
  }

  final WorkoutSession session;
  final WorkoutTimerService timer;
  final void Function(Map<String, dynamic>? snapshot)? onPersist;
  final Clock _clock;

  final Set<String> _roundDone = {};
  List<String>? _pendingTargets;
  bool _disposed = false;

  /// Incrementato a ogni serie registrata (UI: feedback visivo/aptico).
  int eventCount = 0;
  RestEndReason? lastRestEnd;

  // ---- Interrogazioni ---------------------------------------------------

  SessionExercise? byId(String id) {
    for (final e in session.exercises) {
      if (e.exerciseId == id) return e;
    }
    return null;
  }

  List<SessionExercise> blockOf(SessionExercise e) {
    if (e.blockId == null) return [e];
    final m = session.exercises.where((x) => x.blockId == e.blockId).toList();
    return m.isEmpty ? [e] : m;
  }

  List<SessionExercise> _activeMembers(SessionExercise e) =>
      blockOf(e).where((m) => !m.isFinished).toList();

  bool isSuperset(SessionExercise e) => blockOf(e).length > 1;

  bool isRoundDone(SessionExercise e) => _roundDone.contains(e.exerciseId);

  /// `true` se «SERIE FATTA» su questo esercizio avvia il recupero.
  bool isRestTrigger(SessionExercise e) {
    final active = _activeMembers(e);
    return active.isNotEmpty && active.last.exerciseId == e.exerciseId;
  }

  bool isResting(SessionExercise e) =>
      timer.isRunning && (_pendingTargets?.contains(e.exerciseId) ?? false);

  String? get restLabel {
    final t = _pendingTargets;
    if (t == null || !timer.isRunning) return null;
    final names = <String>[];
    for (final id in t) {
      final e = byId(id);
      if (e != null) names.add(e.category.trim().isNotEmpty ? e.category : e.name);
    }
    return names.join(' + ');
  }

  // ---- Azioni -------------------------------------------------------------

  void advance(SessionExercise e) {
    if (e.isFinished || isResting(e)) return;

    final active = _activeMembers(e);
    if (active.length > 1 && active.last.exerciseId != e.exerciseId) {
      if (!_roundDone.add(e.exerciseId)) _roundDone.remove(e.exerciseId);
      _changed();
      return;
    }

    final targets = active.map((m) => m.exerciseId).toList();
    if (targets.isEmpty) return;

    // Chiude il recupero precedente (una sola registrazione).
    if (_pendingTargets != null || timer.isRunning) {
      timer.cancel();
      _creditPending();
    }
    for (final m in blockOf(e)) {
      _roundDone.remove(m.exerciseId);
    }
    _pendingTargets = targets;

    var rest = 0;
    for (final m in blockOf(e)) {
      if (m.restSeconds > rest) rest = m.restSeconds;
    }
    if (rest <= 0) {
      _creditPending();
      lastRestEnd = RestEndReason.skipped;
      eventCount++;
    } else {
      timer.start(rest);
    }
    _changed();
  }

  void skipRest() => timer.skip();

  void adjustRest(int deltaSeconds) {
    timer.adjust(deltaSeconds);
    if (!_disposed) _persist();
  }

  void adjustWeight(SessionExercise e, double deltaKg) {
    final next = ((e.weightKg + deltaKg) * 100).round() / 100;
    e.weightKg = next < 0 ? 0 : next;
    _changed();
  }

  void adjustSets(SessionExercise e, int delta) {
    final next = (e.totalSets + delta).clamp(1, 99);
    e.totalSets = next;
    if (e.completedSets > next) e.completedSets = next;
    _changed();
  }

  void resetExercise(SessionExercise e) {
    if (isResting(e)) return;
    e.completedSets = 0;
    _roundDone.remove(e.exerciseId);
    _changed();
  }

  /// Conclude la sessione: ferma il timer, registra l'eventuale serie in
  /// attesa e imposta l'ora di fine.
  WorkoutSession finish() {
    timer.cancel();
    _creditPending();
    _roundDone.clear();
    session.endedAt = _clock();
    if (!_disposed) notifyListeners();
    return session;
  }

  // ---- Interni --------------------------------------------------------------

  void _onRestFinished(RestEndReason reason) {
    _creditPending();
    lastRestEnd = reason;
    eventCount++;
    _changed();
  }

  /// Registra le serie in attesa. Il campo viene azzerato PRIMA di
  /// incrementare: impossibile doppio completamento.
  void _creditPending() {
    final t = _pendingTargets;
    _pendingTargets = null;
    if (t == null) return;
    for (final id in t) {
      final ex = byId(id);
      if (ex != null && ex.completedSets < ex.totalSets) ex.completedSets++;
    }
  }

  void _changed() {
    if (_disposed) return;
    notifyListeners();
    _persist();
  }

  void _persist() => onPersist?.call(toSnapshot());

  Map<String, dynamic> toSnapshot() => {
        'session': session.toJson(),
        'rest_ends_at': timer.endsAt?.millisecondsSinceEpoch,
        'rest_total_ms': timer.total.inMilliseconds,
        'pending': _pendingTargets,
        'round_done': _roundDone.toList(),
      };

  void _applySnapshot(Map<String, dynamic> snap) {
    final done = snap['round_done'];
    if (done is List) _roundDone.addAll(done.whereType<String>());
    final pending = snap['pending'];
    if (pending is List) _pendingTargets = pending.whereType<String>().toList();
    if (_pendingTargets == null) return;
    final ends = snap['rest_ends_at'];
    if (ends is int) {
      final totalMs = (snap['rest_total_ms'] as num?)?.toInt() ?? 0;
      timer.restore(DateTime.fromMillisecondsSinceEpoch(ends),
          Duration(milliseconds: totalMs));
    } else {
      _creditPending();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    timer.dispose();
    super.dispose();
  }
}
