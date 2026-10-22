import 'dart:io';

import 'package:courtstrength/models/workout_session.dart';
import 'package:courtstrength/screens/home_screen.dart';
import 'package:courtstrength/services/workout_import_export_service.dart';
import 'package:courtstrength/services/workout_storage_service.dart';
import 'package:courtstrength/state/app_state.dart';
import 'package:courtstrength/utils/app_theme.dart';
import 'package:courtstrength/widgets/exercise_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

void main() {
  testWidgets('Home: stato vuoto con azioni per creare/importare', (tester) async {
    final dir = Directory.systemTemp.createTempSync('cs_widget_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final state = AppState(
      storage: WorkoutStorageService(dir),
      importExport: WorkoutImportExportService(),
    );
    await tester.runAsync(() => state.init(seedSamples: false));

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Nessun programma'), findsOneWidget);
    expect(find.text('CREA PROGRAMMA'), findsOneWidget);
    expect(find.text('IMPORTA DA FILE'), findsOneWidget);
  });

  testWidgets('Home: mostra le card dei programmi salvati', (tester) async {
    final dir = Directory.systemTemp.createTempSync('cs_widget_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final state = AppState(
      storage: WorkoutStorageService(dir),
      importExport: WorkoutImportExportService(),
    );
    await tester.runAsync(() async {
      await state.init(seedSamples: false);
      await state.saveWorkout(sampleWorkout());
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Upper Body'), findsOneWidget);
    expect(find.text('INIZIA ALLENAMENTO'), findsOneWidget);
    expect(find.text('3 esercizi'), findsOneWidget);
  });

  testWidgets('ExerciseCard: pulsanti carico, serie e azione principale', (tester) async {
    final e = SessionExercise.fromExercise(sampleWorkout().exercises[2]); // Squat, 80 kg
    var advanced = 0;
    double weightDelta = 0;
    var setsDelta = 0;

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExerciseCard(
            exercise: e,
            accent: AppColors.lime,
            isSuperset: false,
            isRestTrigger: true,
            roundDone: false,
            resting: false,
            onAdvance: () => advanced++,
            onWeightDelta: (d) => weightDelta += d,
            onSetsDelta: (d) => setsDelta += d,
            onReset: () {},
          ),
        ),
      ),
    ));

    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('weight_plus')));
    await tester.tap(find.byKey(const Key('weight_minus')));
    await tester.tap(find.byKey(const Key('sets_plus')));
    await tester.tap(find.text('SERIE FATTA · RECUPERO'));

    expect(weightDelta, 0); // +2.5 e -2.5
    expect(setsDelta, 1);
    expect(advanced, 1);
  });

  testWidgets('ExerciseCard: il pulsante "meno" carico è disattivato a 0 kg', (tester) async {
    final e = SessionExercise.fromExercise(sampleWorkout().exercises[2])..weightKg = 0;
    var delta = 0.0;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExerciseCard(
            exercise: e,
            accent: AppColors.lime,
            isSuperset: false,
            isRestTrigger: true,
            roundDone: false,
            resting: false,
            onAdvance: () {},
            onWeightDelta: (d) => delta += d,
            onSetsDelta: (_) {},
            onReset: () {},
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('weight_minus')));
    expect(delta, 0);
  });

  testWidgets('ExerciseCard: esercizio completato mostra COMPLETATO', (tester) async {
    final e = SessionExercise.fromExercise(sampleWorkout().exercises[2])..completedSets = 2;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExerciseCard(
            exercise: e,
            accent: AppColors.lime,
            isSuperset: false,
            isRestTrigger: true,
            roundDone: false,
            resting: false,
            onAdvance: () {},
            onWeightDelta: (_) {},
            onSetsDelta: (_) {},
            onReset: () {},
          ),
        ),
      ),
    ));
    expect(find.text('COMPLETATO'), findsOneWidget);
  });
}
