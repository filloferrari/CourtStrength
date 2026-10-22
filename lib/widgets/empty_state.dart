import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.onCreate, required this.onImport});

  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: AppColors.lime.withAlpha(28),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center, size: 52, color: AppColors.lime),
            ),
            const SizedBox(height: 28),
            const Text(
              'Nessun programma',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Text(
              'Crea il tuo primo programma di allenamento oppure importalo da un file JSON.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('CREA PROGRAMMA'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('IMPORTA DA FILE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
