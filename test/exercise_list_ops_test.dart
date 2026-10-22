import 'package:courtstrength/models/exercise.dart';
import 'package:courtstrength/utils/exercise_list_ops.dart';
import 'package:flutter_test/flutter_test.dart';

List<Exercise> base() => const [
      Exercise(id: '1', name: 'Uno'),
      Exercise(id: '2', name: 'Due'),
      Exercise(id: '3', name: 'Tre'),
    ];

void main() {
  test('riordino (semantica ReorderableListView)', () {
    expect(ExerciseListOps.reorder(base(), 0, 3).map((e) => e.id), ['2', '3', '1']);
    expect(ExerciseListOps.reorder(base(), 2, 0).map((e) => e.id), ['3', '1', '2']);
    expect(ExerciseListOps.reorder(base(), 1, 2).map((e) => e.id), ['1', '2', '3']);
  });

  test('raggruppa con il precedente crea il blocco e le categorie', () {
    final r = ExerciseListOps.groupWithPrevious(base(), 1);
    expect(r[0].blockId, 'A');
    expect(r[1].blockId, 'A');
    expect(r[2].blockId, isNull);
    expect(r[0].category, 'A1');
    expect(r[1].category, 'A2');
  });

  test('raggruppare un terzo esercizio estende il blocco esistente', () {
    var r = ExerciseListOps.groupWithPrevious(base(), 1);
    r = ExerciseListOps.groupWithPrevious(r, 2);
    expect(r.map((e) => e.blockId), ['A', 'A', 'A']);
  });

  test('il nuovo blocco usa la prima lettera libera', () {
    final list = [
      const Exercise(id: '1', name: 'x', blockId: 'A'),
      const Exercise(id: '2', name: 'y'),
      const Exercise(id: '3', name: 'z'),
    ];
    final r = ExerciseListOps.groupWithPrevious(list, 2);
    expect(r[1].blockId, 'B');
    expect(r[2].blockId, 'B');
  });

  test('rimuovi dal blocco', () {
    final grouped = ExerciseListOps.groupWithPrevious(base(), 1);
    final r = ExerciseListOps.removeFromBlock(grouped, 1);
    expect(r[1].blockId, isNull);
    expect(r[0].blockId, 'A');
  });

  test('duplica inserisce una copia con nuovo id subito dopo', () {
    final r = ExerciseListOps.duplicate(base(), 0);
    expect(r, hasLength(4));
    expect(r[1].name, 'Uno');
    expect(r[1].id, isNot('1'));
  });

  test('elimina e sostituisci', () {
    expect(ExerciseListOps.removeAt(base(), 1).map((e) => e.id), ['1', '3']);
    final r = ExerciseListOps.replaceAt(
        base(), 1, const Exercise(id: '2', name: 'Modificato', sets: 5));
    expect(r[1].name, 'Modificato');
    expect(r[1].sets, 5);
  });

  test('indici non validi non modificano la lista', () {
    expect(ExerciseListOps.removeAt(base(), 9), hasLength(3));
    expect(ExerciseListOps.groupWithPrevious(base(), 0), hasLength(3));
  });
}
