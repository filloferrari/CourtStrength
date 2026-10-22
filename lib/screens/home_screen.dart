import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../state/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/workout_json_parser.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/import_preview_sheet.dart';
import '../widgets/workout_card.dart';
import 'history_screen.dart';
import 'workout_editor_screen.dart';
import 'workout_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 1,
        title: const _Logo(),
                actions: [
          IconButton(
            tooltip: 'Storico allenamenti',
            icon: const Icon(Icons.history),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const HistoryScreen())),
          ),
          IconButton(
            tooltip: 'Importa programma',
            icon: const Icon(Icons.file_open_outlined),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: () => _import(context),
          ),
          PopupMenuButton<String>(
            tooltip: 'Altro',
            padding: EdgeInsets.zero,
            onSelected: (v) {
              if (v == 'export_all') {
                _export(context, app.workouts, 'tutti_i_programmi');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'export_all',
                enabled: app.workouts.isNotEmpty,
                child: const Text('Esporta tutti i programmi'),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(context, app),
      floatingActionButton: app.loading
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _create(context),
              icon: const Icon(Icons.add),
              label: const Text('NUOVO PROGRAMMA'),
            ),
    );
  }

  Widget _buildBody(BuildContext context, AppState app) {
    if (app.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (app.loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(app.loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger)),
        ),
      );
    }
    final snap = app.activeSnapshot;
    if (app.workouts.isEmpty && snap == null) {
      return EmptyState(
        onCreate: () => _create(context),
        onImport: () => _import(context),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        if (snap != null) _ResumeBanner(snapshot: snap),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Text('I TUOI PROGRAMMI',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  fontSize: 12)),
        ),
        for (final w in app.workouts)
          WorkoutCard(
            key: ValueKey(w.id),
            workout: w,
            onStart: () => _start(context, w),
            onAction: (a) => _onAction(context, w, a),
          ),
      ],
    );
  }

  // ---- Azioni -------------------------------------------------------------

  Future<void> _create(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => const WorkoutEditorScreen()),
    );
  }

  Future<void> _start(BuildContext context, Workout w) async {
    final app = context.read<AppState>();
    if (app.activeSnapshot != null) {
      final ok = await showConfirmDialog(
        context,
        title: 'Allenamento in corso',
        message:
            'Hai già un allenamento in pausa. Iniziandone uno nuovo quello precedente verrà scartato.',
        confirmLabel: 'SCARTA E INIZIA',
        destructive: true,
      );
      if (!ok || !context.mounted) return;
      await app.updateActiveSnapshot(null);
      if (!context.mounted) return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => WorkoutScreen(workout: w)),
    );
  }

  Future<void> _onAction(BuildContext context, Workout w, WorkoutCardAction a) async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    switch (a) {
      case WorkoutCardAction.edit:
        await Navigator.of(context).push(
          MaterialPageRoute<bool>(builder: (_) => WorkoutEditorScreen(workout: w)),
        );
      case WorkoutCardAction.duplicate:
        try {
          await app.duplicateWorkout(w.id);
          messenger.showSnackBar(const SnackBar(content: Text('Programma duplicato.')));
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('Duplicazione non riuscita: $e')));
        }
      case WorkoutCardAction.export:
        await _export(context, [w], w.title);
      case WorkoutCardAction.delete:
        final ok = await showConfirmDialog(
          context,
          title: 'Eliminare il programma?',
          message: '«${w.title}» verrà eliminato definitivamente. '
              'Suggerimento: esportalo prima se vuoi conservarne una copia.',
          confirmLabel: 'ELIMINA',
          destructive: true,
        );
        if (!ok) return;
        try {
          await app.deleteWorkout(w.id);
          messenger.showSnackBar(const SnackBar(content: Text('Programma eliminato.')));
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('Eliminazione non riuscita: $e')));
        }
    }
  }

  Future<void> _import(BuildContext context) async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    ImportParseResult? picked;
    try {
      picked = await app.importExport.pickAndParse();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Impossibile aprire il file: $e')));
      return;
    }
    if (picked == null) return; // selezione annullata
    final ImportParseResult result = picked;
    if (!context.mounted) return;

    if (!result.isUsable) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importazione non riuscita',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Text(
              [
                if (result.fatalError != null) result.fatalError!,
                ...result.errors,
              ].join('\n\n'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final decisions = await showImportPreview(context, result, app.findConflict);
    if (decisions == null || decisions.isEmpty) return;
    try {
      final n = await app.importWorkouts(decisions);
      messenger.showSnackBar(SnackBar(
          content: Text(n == 1 ? 'Programma importato.' : '$n programmi importati.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Importazione non riuscita: $e. '
              'I programmi esistenti non sono stati modificati.')));
    }
  }

  Future<void> _export(BuildContext context, List<Workout> list, String baseName) async {
    if (list.isEmpty) return;
    final svc = context.read<AppState>().importExport;
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Salva sul dispositivo'),
                onTap: () => Navigator.of(ctx).pop('save'),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Condividi'),
                onTap: () => Navigator.of(ctx).pop('share'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;
    final json = svc.buildExportJson(list);
    final name = svc.suggestFileName(baseName);
    try {
      if (choice == 'save') {
                final saved = await svc.saveToDevice(name, json);
        if (saved) {
          messenger.showSnackBar(const SnackBar(content: Text('File salvato.')));
        }
      } else {
        await svc.shareFile(name, json);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Esportazione non riuscita: $e')));
    }
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.bolt, color: Colors.black, size: 20),
        ),
        const SizedBox(width: 10),
        const Text.rich(
          TextSpan(children: [
            TextSpan(text: 'COURT '),
            TextSpan(text: 'STRENGTH', style: TextStyle(color: AppColors.lime)),
          ]),
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 20),
        ),
      ],
    );
  }
}

class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({required this.snapshot});
  final Map<String, dynamic> snapshot;

  @override
  Widget build(BuildContext context) {
    final session = snapshot['session'];
    final title = session is Map ? (session['workout_title'] as String? ?? '') : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lime.withAlpha(24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lime.withAlpha(150)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ALLENAMENTO IN PAUSA',
              style: TextStyle(
                  color: AppColors.lime,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  fontSize: 12)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final app = context.read<AppState>();
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Scartare l\'allenamento?',
                      message: 'I progressi di questa sessione andranno persi.',
                      confirmLabel: 'SCARTA',
                      destructive: true,
                    );
                    if (ok) await app.updateActiveSnapshot(null);
                  },
                  child: const Text('SCARTA'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => WorkoutScreen(snapshot: snapshot)),
                  ),
                  child: const Text('RIPRENDI'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
