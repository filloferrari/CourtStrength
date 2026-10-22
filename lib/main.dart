import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/workout_import_export_service.dart';
import 'services/workout_storage_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final appState = AppState(
    storage: WorkoutStorageService(dir),
    importExport: WorkoutImportExportService(),
  );
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const CourtStrengthApp(),
    ),
  );
  // Il caricamento parte dopo il primo frame: la Home mostra uno spinner.
  await appState.init();
}