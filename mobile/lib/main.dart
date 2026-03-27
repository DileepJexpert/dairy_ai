import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/app/router.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: DairyAIApp()));
}

class DairyAIApp extends ConsumerStatefulWidget {
  const DairyAIApp({super.key});

  @override
  ConsumerState<DairyAIApp> createState() => _DairyAIAppState();
}

class _DairyAIAppState extends ConsumerState<DairyAIApp> {
  @override
  void initState() {
    super.initState();
    // Try to restore a previous session from secure storage.
    Future.microtask(
      () => ref.read(authProvider.notifier).tryRestoreSession(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: DairyTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
