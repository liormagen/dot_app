import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/audio_service.dart';
import 'services/progress_service.dart';
import 'services/purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow all orientations on iPad
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize services
  final progressService = ProgressService();
  await progressService.init();

  final audioService = AudioService();
  await audioService.init();

  final purchaseService = PurchaseService();
  await purchaseService.init();

  runApp(
    ProviderScope(
      overrides: [
        progressServiceProvider.overrideWithValue(progressService),
        audioServiceProvider.overrideWithValue(audioService),
        purchaseServiceProvider.overrideWithValue(purchaseService),
      ],
      child: const DotStoryApp(),
    ),
  );
}
