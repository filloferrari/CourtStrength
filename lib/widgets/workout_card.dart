import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../utils/app_theme.dart';

enum WorkoutCardAction { edit, duplicate, export, delete }

class WorkoutCard extends StatelessWidget {
  const WorkoutCard({
    super.key,
    required this.workout,
    required this.onStart,
    required this.onAction,
  });

  final Workout workout;
  final VoidCallback onStart;
  final ValueChanged<WorkoutCardAction> onAction;

  @override
  Widget build(BuildContext context) {
    final w = workout;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  w.subtitle.isEmpty ? 'PROGRAMMA' : w.subtitle.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.lime,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    fontSize: 12,
                  ),
                ),
              ),
              if (w.isSample)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('ESEMPIO',
                      style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              PopupMenuButton<WorkoutCardAction>(
                tooltip: 'Opzioni',
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                onSelected: onAction,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: WorkoutCardAction.edit,
                      child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Modifica'),
                          contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(
                      value: WorkoutCardAction.duplicate,
                      child: ListTile(
                          leading: Icon(Icons.copy_outlined),
                          title: Text('Duplica'),
                          contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(
                      value: WorkoutCardAction.export,
                      child: ListTile(
                          leading: Icon(Icons.ios_share),
                          title: Text('Esporta'),
                          contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(
                      value: WorkoutCardAction.delete,
                      child: ListTile(
                          leading: Icon(Icons.delete_outline, color: AppColors.danger),
                          title: Text('Elimina',
                              style: TextStyle(color: AppColors.danger)),
                          contentPadding: EdgeInsets.zero)),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.title,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
                if (w.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(w.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14, height: 1.35)),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(icon: Icons.timer_outlined, label: '${w.estimatedMinutes} min'),
                    _InfoChip(
                        icon: Icons.fitness_center,
                        label: w.exercisesCount == 1
                            ? '1 esercizio'
                            : '${w.exercisesCount} esercizi'),
                    if (w.supersetCount > 0)
                      _InfoChip(icon: Icons.link, label: '${w.supersetCount} superset'),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text('INIZIA ALLENAMENTO'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
