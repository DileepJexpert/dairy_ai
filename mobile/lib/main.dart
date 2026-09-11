import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/app/router.dart';
import 'package:dairy_ai/app/store_theme.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';

class AppLoggerObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    debugPrint(
        '[RIVERPOD UPDATE] ${provider.name ?? provider.runtimeType}: $newValue');
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    debugPrint(
        '[RIVERPOD ERROR] ${provider.name ?? provider.runtimeType}: $error\n$stackTrace');
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[APP] Initializing Milterra storefront...');

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FLUTTER_ERROR: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint('${details.stack}');
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('ASYNC_ERROR: $error\n$stack');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: storeCream,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(StoreLayout.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: storeError, size: 36),
              const SizedBox(height: StoreLayout.sm),
              const Text('Something went wrong', style: StoreType.title),
              const SizedBox(height: StoreLayout.xs),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: StoreType.muted,
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(ProviderScope(observers: [AppLoggerObserver()], child: const DairyAIApp()));
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
      theme: StoreTheme.light,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
