import '../models/exercise.dart';

/// Operazioni pure sulla lista di esercizi dell'editor (testabili senza UI).
class ExerciseListOps {
  ExerciseListOps._();

  /// Semantica di `ReorderableListView.onReorder`.
  static List<Exercise> reorder(List<Exercise> list, int oldIndex, int newIndex) {
    final r = List<Exercise>.of(list);
    if (oldIndex < 0 || oldIndex >= r.length) return r;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, r.length - 1);
    final item = r.removeAt(oldIndex);
    r.insert(newIndex, item);
    return r;
  }

  static String nextBlockId(List<Exercise> list) {
    final used = list.map((e) => e.blockId).whereType<String>().toSet();
    for (var i = 0; i < 26; i++) {
      final c = String.fromCharCode(65 + i);
      if (!used.contains(c)) return c;
    }
    var n = 1;
    while (used.contains('B$n')) {
      n++;
    }
    return 'B$n';
  }

  /// Inserisce l'esercizio [index] nel blocco di quello precedente
  /// (creando il blocco se non esiste).
  static List<Exercise> groupWithPrevious(List<Exercise> list, int index) {
    if (index <= 0 || index >= list.length) return list;
    final r = List<Exercise>.of(list);
    final prev = r[index - 1];
    final bid = prev.blockId ?? nextBlockId(list);
    r[index - 1] = prev.copyWith(blockId: bid);
    r[index] = r[index].copyWith(blockId: bid);
    var n = 0;
    for (var i = 0; i < r.length; i++) {
      if (r[i].blockId == bid) {
        n++;
        if (r[i].category.trim().isEmpty) {
          r[i] = r[i].copyWith(category: '$bid$n');
        }
      }
    }
    return r;
  }

  static List<Exercise> removeFromBlock(List<Exercise> list, int index) {
    if (index < 0 || index >= list.length) return list;
    final r = List<Exercise>.of(list);
    r[index] = r[index].copyWith(clearBlock: true);
    return r;
  }

  static List<Exercise> duplicate(List<Exercise> list, int index) {
    if (index < 0 || index >= list.length) return list;
    final r = List<Exercise>.of(list);
    r.insert(index + 1, r[index].copyWith(id: newId()));
    return r;
  }

  static List<Exercise> removeAt(List<Exercise> list, int index) {
    if (index < 0 || index >= list.length) return list;
    final r = List<Exercise>.of(list);
    r.removeAt(index);
    return r;
  }

  static List<Exercise> replaceAt(List<Exercise> list, int index, Exercise e) {
    if (index < 0 || index >= list.length) return list;
    final r = List<Exercise>.of(list);
    r[index] = e;
    return r;
  }
}
