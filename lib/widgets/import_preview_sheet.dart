import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../state/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/workout_json_parser.dart';

/// Riepilogo pre-importazione. Ritorna le decisioni confermate oppure `null`
/// se l'utente annulla (nessun dato viene salvato prima della conferma).
Future<List<ImportDecision>?> showImportPreview(
  BuildContext context,
  ImportParseResult result,
  Workout? Function(Workout) findConflict,
) {
  return showModalBottomSheet<List<ImportDecision>>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _ImportPreviewSheet(result: result, findConflict: findConflict),
  );
}

class _ImportPreviewSheet extends StatefulWidget {
  const _ImportPreviewSheet({required this.result, required this.findConflict});

  final ImportParseResult result;
  final Workout? Function(Workout) findConflict;

  @override
  State<_ImportPreviewSheet> createState() => _ImportPreviewSheetState();
}

class _ImportPreviewSheetState extends State<_ImportPreviewSheet> {
  late final List<ImportDecision> _decisions;

  @override
  void initState() {
    super.initState();
    _decisions = [
      for (final w in widget.result.workouts)
        ImportDecision(
          workout: w,
          action: ImportAction.add,
          existing: widget.findConflict(w),
        ),
    ];
  }

  int get _count =>
      _decisions.where((d) => d.action != ImportAction.skip).length;

  @override
  Widget build(BuildContext context) {
    final errors = widget.result.errors;
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Importa programmi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              'Controlla il riepilogo: nulla viene salvato finché non confermi.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final d in _decisions) _buildItem(d),
                  if (errors.isNotEmpty) _buildErrors(errors),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('ANNULLA'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _count == 0
                        ? null
                        : () => Navigator.of(context).pop(
                              _decisions
                                  .where((d) => d.action != ImportAction.skip)
                                  .toList(),
                            ),
                    child: Text('IMPORTA ($_count)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(ImportDecision d) {
    final w = d.workout;
    final hasConflict = d.existing != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: hasConflict ? AppColors.orange.withAlpha(150) : AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(w.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (w.subtitle.isNotEmpty)
            Text(w.subtitle, style: const TextStyle(color: AppColors.lime)),
          const SizedBox(height: 6),
          Text(
            '${w.exercisesCount} esercizi · ${w.estimatedMinutes} min'
            '${w.supersetCount > 0 ? ' · ${w.supersetCount} superset' : ''}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (hasConflict)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppColors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Esiste già «${d.existing!.title}»',
                        style: const TextStyle(color: AppColors.orange)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          DropdownButton<ImportAction>(
            value: d.action,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: AppColors.cardHigh,
            items: [
              DropdownMenuItem(
                value: ImportAction.add,
                child: Text(hasConflict ? 'Importa come copia' : 'Importa'),
              ),
              if (hasConflict)
                const DropdownMenuItem(
                  value: ImportAction.replace,
                  child: Text('Sostituisci quello esistente'),
                ),
              const DropdownMenuItem(
                value: ImportAction.skip,
                child: Text('Non importare'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => d.action = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrors(List<String> errors) {
    final shown = errors.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withAlpha(25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.danger.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            errors.length == 1
                ? '1 programma scartato perché non valido:'
                : '${errors.length} problemi nel file (programmi scartati):',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger),
          ),
          const SizedBox(height: 6),
          for (final e in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $e', style: const TextStyle(fontSize: 13)),
            ),
          if (errors.length > shown.length)
            Text('… e altri ${errors.length - shown.length}',
                style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
