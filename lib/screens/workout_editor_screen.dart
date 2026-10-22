import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exercise.dart';
import '../models/workout.dart';
import '../state/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/exercise_list_ops.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/exercise_edit_sheet.dart';

enum _ExerciseMenu { edit, duplicate, group, ungroup, delete }

/// Editor di un programma (nuovo o esistente). Lavora su una bozza locale:
/// nulla viene scritto finché l'utente non preme SALVA.
class WorkoutEditorScreen extends StatefulWidget {
  const WorkoutEditorScreen({super.key, this.workout});

  final Workout? workout;

  @override
  State<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _description;
  late final TextEditingController _duration;
  late List<Exercise> _exercises;
  bool _dirty = false;
  bool _saving = false;
  String? _exerciseError;

  @override
  void initState() {
    super.initState();
    final w = widget.workout;
    _title = TextEditingController(text: w?.title ?? '');
    _subtitle = TextEditingController(text: w?.subtitle ?? '');
    _description = TextEditingController(text: w?.description ?? '');
    _duration = TextEditingController(
        text: (w != null && w.durationMinutes > 0) ? w.durationMinutes.toString() : '');
    _exercises = List<Exercise>.of(w?.exercises ?? const <Exercise>[]);
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _description.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<bool> _confirmDiscard() => showConfirmDialog(
        context,
        title: 'Scartare le modifiche?',
        message: 'Le modifiche non salvate andranno perse.',
        confirmLabel: 'SCARTA',
        destructive: true,
      );

  void _setExercises(List<Exercise> next) {
    setState(() {
      _exercises = next;
      _dirty = true;
      _exerciseError = null;
    });
  }

  Future<void> _addExercise() async {
    final e = await showExerciseEditSheet(context);
    if (e == null || !mounted) return;
    _setExercises([..._exercises, e]);
  }

  Future<void> _editExercise(int index) async {
    final e = await showExerciseEditSheet(context, initial: _exercises[index]);
    if (e == null || !mounted) return;
    _setExercises(ExerciseListOps.replaceAt(_exercises, index, e));
  }

  Future<void> _onMenu(_ExerciseMenu action, int index) async {
    switch (action) {
      case _ExerciseMenu.edit:
        await _editExercise(index);
      case _ExerciseMenu.duplicate:
        _setExercises(ExerciseListOps.duplicate(_exercises, index));
      case _ExerciseMenu.group:
        _setExercises(ExerciseListOps.groupWithPrevious(_exercises, index));
      case _ExerciseMenu.ungroup:
        _setExercises(ExerciseListOps.removeFromBlock(_exercises, index));
      case _ExerciseMenu.delete:
        final ok = await showConfirmDialog(
          context,
          title: 'Eliminare l\'esercizio?',
          message: '«${_exercises[index].name}» verrà rimosso dal programma.',
          confirmLabel: 'ELIMINA',
          destructive: true,
        );
        if (ok && mounted) _setExercises(ExerciseListOps.removeAt(_exercises, index));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (_exercises.isEmpty) {
      setState(() => _exerciseError = 'Aggiungi almeno un esercizio.');
      return;
    }
    if (!valid) return;
    setState(() => _saving = true);
    final app = context.read<AppState>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final old = widget.workout;
    final w = Workout(
      id: old?.id ?? newId(),
      title: _title.text.trim(),
      subtitle: _subtitle.text.trim(),
      description: _description.text.trim(),
      durationMinutes: int.tryParse(_duration.text.trim()) ?? 0,
      exercises: _exercises,
      isSample: false,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await app.saveWorkout(w);
      if (!mounted) return;
      nav.pop(true);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Salvataggio non riuscito: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = blockColors(_exercises.map((e) => e.blockId));
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.workout == null ? 'Nuovo programma' : 'Modifica programma'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text('SALVA'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Titolo *'),
                      validator: (v) =>
                          Validators.requiredText(v, message: 'Inserisci un titolo'),
                      onChanged: (_) => _markDirty(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _subtitle,
                      decoration: const InputDecoration(
                          labelText: 'Sottotitolo / categoria', hintText: 'Strength'),
                      onChanged: (_) => _markDirty(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Descrizione'),
                      onChanged: (_) => _markDirty(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _duration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Durata stimata (minuti)',
                        helperText: 'Lascia vuoto per calcolarla automaticamente',
                      ),
                      validator: (v) =>
                          Validators.optionalIntInRange(v, min: 1, max: 1440),
                      onChanged: (_) => _markDirty(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text('ESERCIZI',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                                fontSize: 12)),
                        const Spacer(),
                        Text('${_exercises.length}',
                            style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_exercises.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: const Text(
                          'Nessun esercizio. Aggiungine uno con il pulsante qui sotto.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverReorderableList(
                  itemCount: _exercises.length,
                  onReorder: (oldIndex, newIndex) => _setExercises(
                      ExerciseListOps.reorder(_exercises, oldIndex, newIndex)),
                  itemBuilder: (context, index) =>
                      _buildItem(context, index, colors),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_exerciseError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_exerciseError!,
                              style: const TextStyle(color: AppColors.danger)),
                        ),
                      OutlinedButton.icon(
                        onPressed: _addExercise,
                        icon: const Icon(Icons.add),
                        label: const Text('AGGIUNGI ESERCIZIO'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, Map<String, Color> colors) {
    final e = _exercises[index];
    final blockColor = e.blockId == null ? null : colors[e.blockId];
    final accent = blockColor ?? AppColors.lime;
    return Padding(
      key: ValueKey(e.id),
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: blockColor != null ? blockColor.withAlpha(150) : AppColors.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _editExercise(index),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            child: Row(
              children: [
                if (e.category.trim().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(40),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(e.category,
                        style: TextStyle(
                            color: accent, fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(
                        '${e.sets} × ${e.reps} · ${formatKg(e.weightKg)} kg · rec ${e.restSeconds} s'
                        '${e.blockId != null ? ' · blocco ${e.blockId}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_ExerciseMenu>(
                  tooltip: 'Opzioni esercizio',
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                  onSelected: (a) => _onMenu(a, index),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: _ExerciseMenu.edit, child: Text('Modifica')),
                    const PopupMenuItem(
                        value: _ExerciseMenu.duplicate, child: Text('Duplica')),
                    if (index > 0)
                      const PopupMenuItem(
                          value: _ExerciseMenu.group,
                          child: Text('Raggruppa con il precedente')),
                    if (e.blockId != null)
                      const PopupMenuItem(
                          value: _ExerciseMenu.ungroup,
                          child: Text('Rimuovi dal blocco')),
                    const PopupMenuItem(
                        value: _ExerciseMenu.delete,
                        child: Text('Elimina',
                            style: TextStyle(color: AppColors.danger))),
                  ],
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
