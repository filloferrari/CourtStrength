import 'package:flutter/material.dart';

import '../models/workout_session.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

/// Card di un esercizio durante l'allenamento.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.accent,
    required this.isSuperset,
    required this.isRestTrigger,
    required this.roundDone,
    required this.resting,
    required this.onAdvance,
    required this.onWeightDelta,
    required this.onSetsDelta,
    required this.onReset,
  });

  static const double weightStep = 2.5;

  final SessionExercise exercise;
  final Color accent;
  final bool isSuperset;
  final bool isRestTrigger;
  final bool roundDone;
  final bool resting;
  final VoidCallback onAdvance;
  final ValueChanged<double> onWeightDelta;
  final ValueChanged<int> onSetsDelta;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final finished = e.isFinished;
    final borderColor = finished
        ? AppColors.lime.withAlpha(170)
        : (isSuperset ? accent.withAlpha(150) : AppColors.outline);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.category.trim().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(e.category,
                      style: TextStyle(
                          color: accent, fontWeight: FontWeight.w900, fontSize: 14)),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800, height: 1.15)),
                    if (e.description.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(e.description,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ),
                  ],
                ),
              ),
              if (finished)
                const Icon(Icons.check_circle, color: AppColors.lime)
              else if (e.completedSets > 0 && !resting)
                IconButton(
                  tooltip: 'Azzera serie',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.restart_alt, color: AppColors.textSecondary),
                  onPressed: onReset,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill(icon: Icons.repeat, label: 'Rip. ${e.reps}'),
              _Pill(icon: Icons.timer_outlined, label: 'Rec. ${e.restSeconds} s'),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: e.totalSets == 0 ? 0 : (e.completedSets / e.totalSets).clamp(0.0, 1.0),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            backgroundColor: const Color(0xFF333333),
            color: finished ? AppColors.lime : accent,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('SERIE'),
                    Text('${e.completedSets}/${e.totalSets}',
                        style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: finished ? AppColors.lime : Colors.white)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StepButton(
                          key: const Key('sets_minus'),
                          icon: Icons.remove,
                          size: 36,
                          onTap: e.totalSets > 1 ? () => onSetsDelta(-1) : null,
                        ),
                        const SizedBox(width: 8),
                        _StepButton(
                          key: const Key('sets_plus'),
                          icon: Icons.add,
                          size: 36,
                          onTap: () => onSetsDelta(1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('CARICO'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StepButton(
                          key: const Key('weight_minus'),
                          icon: Icons.remove,
                          onTap: e.weightKg > 0
                              ? () => onWeightDelta(-weightStep)
                              : null,
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                      text: formatKg(e.weightKg),
                                      style: const TextStyle(
                                          fontSize: 32, fontWeight: FontWeight.w900)),
                                  const TextSpan(
                                      text: ' kg',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ),
                          ),
                        ),
                        _StepButton(
                          key: const Key('weight_plus'),
                          icon: Icons.add,
                          onTap: () => onWeightDelta(weightStep),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: _actionButton()),
        ],
      ),
    );
  }

  Widget _actionButton() {
    final e = exercise;
    if (e.isFinished) {
      return FilledButton.icon(
        onPressed: null,
        icon: Icon(Icons.check),
        label: Text('COMPLETATO'),
      );
    }
    if (resting) {
      return FilledButton.icon(
        onPressed: null,
        icon: Icon(Icons.hourglass_bottom),
        label: Text('IN RECUPERO'),
      );
    }
    if (isSuperset && !isRestTrigger) {
      if (roundDone) {
        return OutlinedButton.icon(
          onPressed: onAdvance,
          icon: const Icon(Icons.check, color: AppColors.lime),
          label: const Text('FATTO · TOCCA PER ANNULLARE'),
        );
      }
      return FilledButton.icon(
        onPressed: onAdvance,
        icon: const Icon(Icons.skip_next_rounded),
        label: const Text('FATTO · PROSSIMO'),
      );
    }
    return FilledButton.icon(
      onPressed: onAdvance,
      icon: const Icon(Icons.timer_outlined),
      label: Text(e.restSeconds > 0 ? 'SERIE FATTA · RECUPERO' : 'SERIE FATTA'),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      );
}

class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.icon, required this.onTap, this.size = 48});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.cardHigh : const Color(0xFF191919),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon,
              size: size * 0.5,
              color: enabled ? Colors.white : const Color(0xFF555555)),
        ),
      ),
    );
  }
}
