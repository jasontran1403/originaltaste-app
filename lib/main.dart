// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_controller.dart';
import 'data/network/dio_client.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Orientation: portrait + landscape ────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // ── Init DioClient ────────────────────────────────────────────
  DioClient.instance.init();

  // ── Set token expired handler → logout ────────────────────────
  DioClient.instance.setOnTokenExpired(() async {
    await AuthService.instance.logout();
    // Router navigate sẽ được xử lý bởi AuthController
  });

  runApp(const ProviderScope(child: OriginalTasteApp()));
}

class OriginalTasteApp extends ConsumerWidget {
  const OriginalTasteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(routerProvider);
    final themeMode = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      title:            'Original Taste',
      debugShowCheckedModeBanner: false,
      theme:      AppTheme.light,
      darkTheme:  AppTheme.dark,
      themeMode:  themeMode,
      routerConfig: router,
    );
  }
}
