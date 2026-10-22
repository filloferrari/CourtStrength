import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/confirm_dialog.dart';
import 'workout_summary_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sessions = app.sessions;
    return Scaffold(
      appBar: AppBar(title: const Text('Storico')),
      body: sessions.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Nessun allenamento completato finora.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: sessions.length,
              itemBuilder: (context, i) {
                final s = sessions[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    title: Text(s.workoutTitle,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      '${formatDateTime(s.startedAt)}\n'
                      '${formatDuration(s.duration)} · ${s.completedSets} serie · ${formatVolume(s.totalVolumeKg)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    isThreeLine: true,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => WorkoutSummaryScreen(session: s, readOnly: true))),
                    trailing: IconButton(
                      tooltip: 'Elimina dallo storico',
                      icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await showConfirmDialog(
                          context,
                          title: 'Eliminare la sessione?',
                          message: 'La sessione verrà rimossa dallo storico.',
                          confirmLabel: 'ELIMINA',
                          destructive: true,
                        );
                        if (!ok) return;
                        try {
                          await app.deleteSession(s.id);
                        } catch (e) {
                          messenger.showSnackBar(
                              SnackBar(content: Text('Eliminazione non riuscita: $e')));
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
