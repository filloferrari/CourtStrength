import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout_session.dart';
import '../state/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/confirm_dialog.dart';

/// Riepilogo di una sessione conclusa (anche in sola lettura dallo storico).
class WorkoutSummaryScreen extends StatefulWidget {
  const WorkoutSummaryScreen({super.key, required this.session, this.readOnly = false});

  final WorkoutSession session;
  final bool readOnly;

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  bool _applied = false;

  void _goHome() {
    if (widget.readOnly) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _applyToProgram() async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'Aggiornare il programma?',
      message:
          'I carichi e il numero di serie usati in questa sessione sostituiranno quelli salvati nel programma.',
      confirmLabel: 'AGGIORNA',
    );
    if (!ok) return;
    try {
      final done = await app.applySessionToWorkout(widget.session);
      if (!mounted) return;
      setState(() => _applied = done);
      messenger.showSnackBar(SnackBar(
          content: Text(done ? 'Programma aggiornato.' : 'Il programma non esiste più.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Aggiornamento non riuscito: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final app = context.watch<AppState>();
    final canApply = !widget.readOnly &&
        !_applied &&
        s.hasChangesFromProgram &&
        app.workoutById(s.workoutId) != null;

    return PopScope(
      canPop: widget.readOnly,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.readOnly,
          title: Text(widget.readOnly ? 'Dettaglio sessione' : 'Riepilogo'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (!widget.readOnly)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.lime.withAlpha(26),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.lime.withAlpha(150)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.emoji_events_outlined, color: AppColors.lime, size: 36),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text('ALLENAMENTO\nCONCLUSO',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              letterSpacing: 0.6)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(s.workoutTitle,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            if (s.workoutSubtitle.isNotEmpty)
              Text(s.workoutSubtitle, style: const TextStyle(color: AppColors.lime)),
            Text(formatDateTime(s.startedAt),
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _Stat(label: 'DURATA', value: formatDuration(s.duration))),
                const SizedBox(width: 12),
                Expanded(
                    child: _Stat(
                        label: 'SERIE', value: '${s.completedSets}/${s.totalSets}')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _Stat(
                        label: 'ESERCIZI',
                        value: '${s.exercisesPerformed}/${s.exercises.length}')),
                const SizedBox(width: 12),
                Expanded(child: _Stat(label: 'VOLUME', value: formatVolume(s.totalVolumeKg))),
              ],
            ),
            if (s.volumeExcludedCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  'Il volume non include ${s.volumeExcludedCount} esercizi con ripetizioni non numeriche (es. AMRAP, 30 sec).',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            const Text('DETTAGLIO',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    fontSize: 12)),
            const SizedBox(height: 8),
            for (final e in s.exercises)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name,
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${formatKg(e.weightKg)} kg · rip. ${e.reps}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    Text('${e.completedSets}/${e.totalSets}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: e.isFinished ? AppColors.lime : Colors.white)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (canApply) ...[
              OutlinedButton.icon(
                onPressed: _applyToProgram,
                icon: const Icon(Icons.save_outlined),
                label: const Text('SALVA CARICHI NEL PROGRAMMA'),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _goHome,
              icon: const Icon(Icons.home_outlined),
              label: Text(widget.readOnly ? 'INDIETRO' : 'TORNA ALLA HOME'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  fontSize: 11)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
