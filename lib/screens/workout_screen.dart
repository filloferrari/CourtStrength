import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/workout.dart';
import '../services/session_controller.dart';
import '../services/workout_timer_service.dart';
import '../services/beep_service.dart';
import '../state/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/exercise_card.dart';
import '../widgets/rest_timer_panel.dart';
import 'workout_summary_screen.dart';

/// Esecuzione di un allenamento. Usa una sessione separata dal programma:
/// carichi e serie modificati qui non alterano il programma salvato.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, this.workout, this.snapshot})
      : assert(workout != null || snapshot != null,
            'Serve un programma o uno snapshot da riprendere');

  final Workout? workout;
  final Map<String, dynamic>? snapshot;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with WidgetsBindingObserver {
  late final SessionController _c;
  int _seenEvents = 0;
  bool _finishing = false;
  final BeepService _beep = BeepService();

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    void persist(Map<String, dynamic>? snap) => unawaited(app.updateActiveSnapshot(snap));
    final snap = widget.snapshot;
    _c = snap != null
        ? SessionController.restore(snap, onPersist: persist)
        : SessionController.start(widget.workout!, onPersist: persist);
    _seenEvents = _c.eventCount;
    _c.addListener(_onController);
    WidgetsBinding.instance.addObserver(this);
    _setWakelock(true);
    if (snap == null) persist(_c.toSnapshot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_onController);
    _c.dispose(); // cancella anche il timer
    _setWakelock(false);
    unawaited(_beep.dispose());
    super.dispose();
  }

  void _setWakelock(bool on) {
    try {
      final f = on ? WakelockPlus.enable() : WakelockPlus.disable();
      f.catchError((Object _) {});
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // La scadenza è assoluta: al ritorno si ricalcola il tempo residuo.
      _c.timer.checkNow();
    }
  }

  void _onController() {
    if (_c.eventCount == _seenEvents) return;
    _seenEvents = _c.eventCount;
    if (!mounted) return;
    final elapsed = _c.lastRestEnd == RestEndReason.elapsed;
    if (elapsed) {
      HapticFeedback.heavyImpact();
      _beep.playRestEnd();
    } else {
      HapticFeedback.selectionClick();
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      content: Text(elapsed ? 'Recupero terminato · serie registrata' : 'Serie registrata'),
    ));
  }

  Future<void> _confirmExit() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uscire dall\'allenamento?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Puoi lasciarlo in pausa e riprenderlo dalla Home, oppure scartarlo.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop('stay'), child: const Text('CONTINUA')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop('pause'), child: const Text('IN PAUSA')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('SCARTA'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'stay') return;
    final app = context.read<AppState>();
    final nav = Navigator.of(context);
    if (choice == 'discard') {
      await app.updateActiveSnapshot(null);
    } else {
      await app.updateActiveSnapshot(_c.toSnapshot());
    }
    if (mounted) nav.pop();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    final incomplete = _c.session.exercises.any((e) => !e.isFinished);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminare l\'allenamento?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          incomplete
              ? 'Alcune serie non sono state completate. Verrà salvato quanto fatto finora.'
              : 'Hai completato tutte le serie. Ottimo lavoro!',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ANNULLA')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('TERMINA')),
        ],
      ),
    );
    if (ok != true || !mounted || _finishing) return;
    _finishing = true;
    final app = context.read<AppState>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final session = _c.finish();
    try {
      await app.recordSession(session);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Impossibile salvare la sessione nello storico: $e')));
    }
    if (!mounted) return;
    nav.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => WorkoutSummaryScreen(session: session)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Torna alla Home',
            icon: const Icon(Icons.arrow_back),
            onPressed: _confirmExit,
          ),
          title: const Text('ALLENAMENTO',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
          actions: [
            TextButton(onPressed: _finish, child: const Text('TERMINA')),
            const SizedBox(width: 8),
          ],
        ),
        body: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            final s = _c.session;
            final colors = blockColors(s.exercises.map((e) => e.blockId));
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      _Header(
                        title: s.workoutTitle,
                        subtitle: s.workoutSubtitle,
                        description: s.workoutDescription,
                        minutes: s.estimatedMinutes,
                        exercises: s.exercises.length,
                        doneSets: s.completedSets,
                        totalSets: s.totalSets,
                      ),
                      const SizedBox(height: 16),
                      for (final e in s.exercises)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ExerciseCard(
                            key: ValueKey(e.exerciseId),
                            exercise: e,
                            accent: (e.blockId != null ? colors[e.blockId] : null) ??
                                AppColors.lime,
                            isSuperset: _c.isSuperset(e),
                            isRestTrigger: _c.isRestTrigger(e),
                            roundDone: _c.isRoundDone(e),
                            resting: _c.isResting(e),
                            onAdvance: () => _c.advance(e),
                            onWeightDelta: (d) => _c.adjustWeight(e, d),
                            onSetsDelta: (d) => _c.adjustSets(e, d),
                            onReset: () => _c.resetExercise(e),
                          ),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _finish,
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('TERMINA ALLENAMENTO'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  child: RestTimerPanel(
                    timer: _c.timer,
                    label: _c.restLabel,
                    onAdjust: _c.adjustRest,
                    onSkip: _c.skipRest,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.minutes,
    required this.exercises,
    required this.doneSets,
    required this.totalSets,
  });

  final String title;
  final String subtitle;
  final String description;
  final int minutes;
  final int exercises;
  final int doneSets;
  final int totalSets;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle.isNotEmpty)
            Text(subtitle.toUpperCase(),
                style: const TextStyle(
                    color: AppColors.lime,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    fontSize: 12)),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.35)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _meta(Icons.timer_outlined, '$minutes min'),
              _meta(Icons.fitness_center, '$exercises esercizi'),
              _meta(Icons.check_circle_outline, '$doneSets/$totalSets serie'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      );
}
