class Validators {
  Validators._();

  static String? requiredText(String? v, {String message = 'Campo obbligatorio'}) {
    if (v == null || v.trim().isEmpty) return message;
    return null;
  }

  static String? intInRange(String? v, {required int min, required int max}) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Inserisci un numero intero';
    if (n < min || n > max) return 'Valore tra $min e $max';
    return null;
  }

  static String? optionalIntInRange(String? v,
      {required int min, required int max}) {
    if (v == null || v.trim().isEmpty) return null;
    return intInRange(v, min: min, max: max);
  }

  /// Accetta sia il punto sia la virgola come separatore decimale.
  static double? parseDecimal(String? v) {
    if (v == null) return null;
    final d = double.tryParse(v.trim().replaceAll(',', '.'));
    if (d == null || d.isNaN || d.isInfinite) return null;
    return d;
  }

  static String? decimalNonNegative(String? v, {double max = 2000}) {
    final d = parseDecimal(v);
    if (d == null) return 'Inserisci un numero';
    if (d < 0) return 'Non può essere negativo';
    if (d > max) return 'Valore massimo $max';
    return null;
  }
}
