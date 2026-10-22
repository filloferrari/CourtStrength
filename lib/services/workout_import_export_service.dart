import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/workout.dart';
import '../utils/workout_json_parser.dart';

/// Importazione/esportazione JSON dei programmi.
class WorkoutImportExportService {
  static const int maxFileBytes = 5 * 1024 * 1024;

  /// Fa scegliere un file all'utente e lo valida. `null` = selezione annullata.
  Future<ImportParseResult?> pickAndParse() async {
    final PlatformFile? f = await FilePicker.pickFile();
    if (f == null) return null;
    final Uint8List bytes = await f.readAsBytes();
    return parseBytes(bytes);
  }

  ImportParseResult parseBytes(List<int> bytes) {
    if (bytes.length > maxFileBytes) {
      return ImportParseResult.fatal('Il file è troppo grande (massimo 5 MB).');
    }
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      return ImportParseResult.fatal('Il file non è testo UTF-8 valido.');
    }
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    return WorkoutJsonParser.parseDocument(text);
  }

  /// JSON documentato con `schemaVersion`.
  String buildExportJson(List<Workout> workouts) {
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': WorkoutJsonParser.currentSchemaVersion,
      'app': 'court_strength',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'workouts': workouts.map((w) => w.toJson(forExport: true)).toList(),
    });
  }

  String suggestFileName(String baseName) {
    final slug = baseName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${d.year}${two(d.month)}${two(d.day)}';
    return 'court_strength_${slug.isEmpty ? 'programma' : slug}_$stamp.json';
  }

  /// Fa scegliere dove salvare il file. Ritorna il percorso, o `null` se annullato.
  Future<bool> saveToDevice(String fileName, String json) async {
    final Uri? saved = await FilePicker.saveFile(
      dialogTitle: 'Salva programma',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
    return saved != null;
  }

  /// Condivisione tramite il foglio di condivisione del sistema.
  Future<void> shareFile(String fileName, String json) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(json, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Court Strength - programma di allenamento',
      ),
    );
  }
}