import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/workout.dart';
import '../models/workout_session.dart';
import '../utils/workout_json_parser.dart';

class StoredLibrary {
  const StoredLibrary({required this.workouts, required this.seeded});
  final List<Workout> workouts;

  /// `true` se i programmi dimostrativi sono già stati inseriti una volta.
  final bool seeded;
}

/// Persistenza locale su file JSON nella cartella documenti dell'app.
///
/// Scritture atomiche (file temporaneo + rename) con copia di backup `.bak`
/// del file precedente; in lettura, se il file principale è corrotto viene
/// messo da parte (`.corrupt-<timestamp>`) e si ripiega sul backup.
/// Tutte le operazioni sono serializzate in coda: niente scritture concorrenti.
class WorkoutStorageService {
  WorkoutStorageService(this.directory);

  final Directory directory;

  static const int schemaVersion = 1;
  static const String _libraryFile = 'workouts.json';
  static const String _sessionsFile = 'sessions.json';
  static const String _activeFile = 'active_session.json';

  Future<void> _queue = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  File _file(String name) => File('${directory.path}${Platform.pathSeparator}$name');

  // ---- Programmi -----------------------------------------------------

  Future<StoredLibrary> loadLibrary() => _enqueue(() async {
        final doc = await _readJson(_libraryFile);
        if (doc == null) return const StoredLibrary(workouts: [], seeded: false);
        final workouts = <Workout>[];
        final raw = doc['workouts'];
        if (raw is List) {
          for (var i = 0; i < raw.length; i++) {
            final item = raw[i];
            if (item is Map) {
              final w = WorkoutJsonParser.parseWorkout(
                  Map<String, dynamic>.from(item), 'Programma ${i + 1}', <String>[]);
              if (w != null) workouts.add(w);
            }
          }
        }
        return StoredLibrary(workouts: workouts, seeded: doc['seeded'] == true);
      });

  Future<void> saveLibrary(List<Workout> workouts, {required bool seeded}) =>
      _enqueue(() => _writeJson(_libraryFile, {
            'schemaVersion': schemaVersion,
            'seeded': seeded,
            'workouts': workouts.map((w) => w.toJson()).toList(),
          }));

  // ---- Storico sessioni ---------------------------------------------

  Future<List<WorkoutSession>> loadSessions() => _enqueue(() async {
        final doc = await _readJson(_sessionsFile);
        final result = <WorkoutSession>[];
        final raw = doc?['sessions'];
        if (raw is List) {
          for (final item in raw) {
            try {
              result.add(WorkoutSession.fromJson(Map<String, dynamic>.from(item as Map)));
            } catch (_) {
              // Sessione illeggibile: ignorata, le altre restano.
            }
          }
        }
        return result;
      });

  Future<void> saveSessions(List<WorkoutSession> sessions) =>
      _enqueue(() => _writeJson(_sessionsFile, {
            'schemaVersion': schemaVersion,
            'sessions': sessions.map((s) => s.toJson()).toList(),
          }));

  // ---- Sessione attiva (per riprendere dopo chiusure accidentali) -----

  Future<Map<String, dynamic>?> loadActiveSession() =>
      _enqueue(() => _readJson(_activeFile));

  Future<void> saveActiveSession(Map<String, dynamic>? snapshot) =>
      _enqueue(() async {
        if (snapshot == null) {
          for (final name in [_activeFile, '$_activeFile.bak', '$_activeFile.tmp']) {
            final f = _file(name);
            if (await f.exists()) await f.delete();
          }
          return;
        }
        await _writeJson(_activeFile, snapshot);
      });

  // ---- Utilità di basso livello ----------------------------------------

  Future<Map<String, dynamic>?> _readJson(String name) async {
    final main = _file(name);
    final fromMain = await _tryRead(main);
    if (fromMain != null) return fromMain;
    if (await main.exists()) {
      try {
        await main.rename(
            '${main.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
      } catch (_) {}
    }
    return _tryRead(_file('$name.bak'));
  }

  Future<Map<String, dynamic>?> _tryRead(File f) async {
    try {
      if (!await f.exists()) return null;
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Future<void> _writeJson(String name, Object data) async {
    await directory.create(recursive: true);
    final target = _file(name);
    final tmp = _file('$name.tmp');
    final bak = _file('$name.bak');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(data),
        flush: true);
    if (await target.exists()) {
      try {
        await target.copy(bak.path);
      } catch (_) {}
    }
    try {
      await tmp.rename(target.path);
    } on FileSystemException {
      if (await target.exists()) await target.delete();
      await tmp.rename(target.path);
    }
  }
}
