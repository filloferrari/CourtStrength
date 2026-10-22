import 'dart:async';

import 'package:flutter/foundation.dart';

typedef Clock = DateTime Function();

enum RestEndReason { elapsed, skipped }

/// Timer di recupero basato su una **scadenza** (`endsAt`) e non sul numero
/// di tick: resta corretto anche se l'app viene sospesa. Il completamento
/// ([onFinished]) viene eseguito una sola volta; il tempo non va mai sotto zero.
class WorkoutTimerService extends ChangeNotifier {
  WorkoutTimerService({
    Clock? clock,
    this._tickInterval = const Duration(milliseconds: 250),
    this.onFinished,
  })  : _clock = clock ?? DateTime.now;

  final Clock _clock;
  final Duration _tickInterval;
  void Function(RestEndReason reason)? onFinished;

  Timer? _ticker;
  DateTime? _endsAt;
  Duration _total = Duration.zero;
  int _lastShown = -1;
  bool _disposed = false;

  bool get isRunning => _endsAt != null;
  DateTime? get endsAt => _endsAt;
  Duration get total => _total;

  Duration get remaining {
    final e = _endsAt;
    if (e == null) return Duration.zero;
    final d = e.difference(_clock());
    return d.isNegative ? Duration.zero : d;
  }

  /// Secondi residui arrotondati per eccesso (00:00 solo a scadenza).
  int get remainingSeconds => (remaining.inMilliseconds / 1000).ceil();

  /// 0..1 (1 = appena partito).
  double get progress {
    if (!isRunning || _total.inMilliseconds <= 0) return 0;
    return (remaining.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Avvia un nuovo timer sostituendo quello eventualmente attivo (senza
  /// invocare [onFinished] per il precedente).
  void start(int seconds) {
    _stopTicker();
    if (seconds <= 0) {
      _endsAt = null;
      _total = Duration.zero;
      _notify();
      return;
    }
    _total = Duration(seconds: seconds);
    _endsAt = _clock().add(_total);
    _lastShown = remainingSeconds;
    _startTicker();
    _notify();
  }

  /// Ripristina un timer da una scadenza salvata. Se è già scaduto,
  /// completa subito (una sola volta).
  void restore(DateTime endsAt, Duration total) {
    _stopTicker();
    _endsAt = endsAt;
    _total = total;
    if (remaining == Duration.zero) {
      _finish(RestEndReason.elapsed);
      return;
    }
    _lastShown = remainingSeconds;
    _startTicker();
    _notify();
  }

  void adjust(int deltaSeconds) {
    final e = _endsAt;
    if (e == null) return;
    _endsAt = e.add(Duration(seconds: deltaSeconds));
    _total += Duration(seconds: deltaSeconds);
    if (remaining == Duration.zero) {
      _finish(RestEndReason.skipped);
      return;
    }
    if (_total < remaining) _total = remaining;
    _lastShown = remainingSeconds;
    _notify();
  }

  /// Salta il recupero: esegue il completamento come a fine timer.
  void skip() {
    if (_endsAt == null) return;
    _finish(RestEndReason.skipped);
  }

  /// Ferma il timer SENZA eseguire il completamento.
  void cancel() {
    final wasRunning = _endsAt != null;
    _stopTicker();
    _endsAt = null;
    _total = Duration.zero;
    if (wasRunning) _notify();
  }

  /// Da chiamare al ritorno in primo piano dell'app.
  void checkNow() {
    if (_endsAt == null) return;
    if (remaining == Duration.zero) {
      _finish(RestEndReason.elapsed);
      return;
    }
    final s = remainingSeconds;
    if (s != _lastShown) {
      _lastShown = s;
      _notify();
    }
  }

  void _finish(RestEndReason reason) {
    if (_endsAt == null) return; // evita doppi completamenti
    _endsAt = null;
    _total = Duration.zero;
    _stopTicker();
    _notify();
    onFinished?.call(reason);
  }

  void _startTicker() {
    _ticker = Timer.periodic(_tickInterval, (_) => checkNow());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTicker();
    _endsAt = null;
    super.dispose();
  }
}
