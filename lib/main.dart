import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/audio_service.dart';
import 'services/progress_service.dart';
import 'services/purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final progressService = ProgressService();
  await progressService.init();

  final audioService = AudioService();
  await audioService.init();

  final purchaseService = PurchaseService();

  final container = ProviderContainer(
    overrides: [
      progressServiceProvider.overrideWithValue(progressService),
      audioServiceProvider.overrideWithValue(audioService),
      purchaseServiceProvider.overrideWithValue(purchaseService),
    ],
  );

  purchaseService.onPurchaseSuccess = () {
    container.read(progressProvider.notifier).setPurchaseUnlocked(true);
  };

  await purchaseService.init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DotStoryApp(),
    ),
  );
}
