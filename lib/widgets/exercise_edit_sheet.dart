import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';

/// Apre il foglio di modifica di un esercizio. Ritorna l'esercizio salvato
/// oppure `null` se annullato.
Future<Exercise?> showExerciseEditSheet(BuildContext context, {Exercise? initial}) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ExerciseEditSheet(initial: initial),
  );
}

class _ExerciseEditSheet extends StatefulWidget {
  const _ExerciseEditSheet({this.initial});
  final Exercise? initial;

  @override
  State<_ExerciseEditSheet> createState() => _ExerciseEditSheetState();
}

class _ExerciseEditSheetState extends State<_ExerciseEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _description;
  late final TextEditingController _sets;
  late final TextEditingController _reps;
  late final TextEditingController _weight;
  late final TextEditingController _rest;
  late final TextEditingController _block;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _name = TextEditingController(text: e?.name ?? '');
    _category = TextEditingController(text: e?.category ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _sets = TextEditingController(text: (e?.sets ?? 3).toString());
    _reps = TextEditingController(text: e?.reps ?? '10');
    _weight = TextEditingController(text: formatKg(e?.weightKg ?? 0));
    _rest = TextEditingController(text: (e?.restSeconds ?? 60).toString());
    _block = TextEditingController(text: e?.blockId ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _category, _description, _sets, _reps, _weight, _rest, _block]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final block = _block.text.trim();
    final base = widget.initial;
    final result = Exercise(
      id: base?.id ?? newId(),
      name: _name.text.trim(),
      category: _category.text.trim(),
      description: _description.text.trim(),
      sets: int.parse(_sets.text.trim()),
      reps: _reps.text.trim(),
      weightKg: ((Validators.parseDecimal(_weight.text) ?? 0) * 100).round() / 100,
      restSeconds: int.parse(_rest.text.trim()),
      blockId: block.isEmpty ? null : block,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.initial == null ? 'Nuovo esercizio' : 'Modifica esercizio',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nome *'),
                validator: (v) =>
                    Validators.requiredText(v, message: 'Inserisci il nome'),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _category,
                      decoration: const InputDecoration(
                          labelText: 'Categoria', hintText: 'A1, B2...'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _block,
                      maxLength: 12,
                      decoration: const InputDecoration(
                          labelText: 'Blocco', hintText: 'A', counterText: ''),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Esercizi con lo stesso blocco formano un superset (nessuna pausa fra loro).',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Descrizione'),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sets,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Serie *'),
                      validator: (v) => Validators.intInRange(v, min: 1, max: 99),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _reps,
                      decoration: const InputDecoration(
                          labelText: 'Ripetizioni *', hintText: '8, 10-12, AMRAP'),
                      validator: (v) =>
                          Validators.requiredText(v, message: 'Obbligatorio'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Carico (kg) *'),
                      validator: (v) => Validators.decimalNonNegative(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _rest,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Recupero (s) *'),
                      validator: (v) => Validators.intInRange(v, min: 0, max: 3600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
                    child: FilledButton(onPressed: _save, child: const Text('SALVA')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
