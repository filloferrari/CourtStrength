
import 'package:flutter/material.dart';

import '../services/workout_timer_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

/// Pannello del recupero, sempre visibile in fondo alla schermata.
class RestTimerPanel extends StatelessWidget {
  const RestTimerPanel({
    super.key,
    required this.timer,
    required this.label,
    required this.onAdjust,
    required this.onSkip,
  });

  final WorkoutTimerService timer;
  final String? label;
  final ValueChanged<int> onAdjust;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: timer,
      builder: (context, _) {
        final running = timer.isRunning;
        final seconds = running ? timer.remainingSeconds : 0;
        final low = running && seconds <= 10;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: running ? AppColors.lime.withAlpha(180) : AppColors.outline,
                width: 1.5),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('RECUPERO',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6)),
                    const Spacer(),
                    if (running && label != null && label!.isNotEmpty)
                      Flexible(
                        child: Text(label!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.lime,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ),
                  ],
                ),
                Text(
                  formatClock(seconds),
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    color: !running
                        ? const Color(0xFF555555)
                        : (low ? AppColors.orange : Colors.white),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (!running)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('Completa una serie per avviare il recupero',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: LinearProgressIndicator(
                      value: timer.progress,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(3),
                      backgroundColor: const Color(0xFF333333),
                      color: low ? AppColors.orange : AppColors.lime,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: running ? () => onAdjust(-15) : null,
                        child: const Text('-15 s'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: running ? onSkip : null,
                        child: const Text('SALTA'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: running ? () => onAdjust(15) : null,
                        child: const Text('+15 s'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
