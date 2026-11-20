import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'core/constants/app_constants.dart';

void main() async {
  // Ensure that Flutter widget binding is initialized before calling native modules
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase only on supported platforms.
  if (kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase web initialization failed: $e');
    }
  } else if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      // On mobile platforms, prefer native configuration (google-services.json / GoogleService-Info.plist)
      // so call initializeApp without options. This allows the Firebase SDK to use platform files.
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase mobile initialization failed: $e');
    }
  } else {
    debugPrint('Firebase initialization skipped for unsupported platform: $defaultTargetPlatform');
  }

  runApp(
    // Wrap entire application inside ProviderScope to enable Riverpod state management
    const ProviderScope(
      child: MyApp(),
    ),
  );

  // After app launch, perform a quick Firestore connectivity check and log the result.

  // After app launch, perform a quick Firestore connectivity check and log the result.
  // This runs non-blocking and helps confirm whether the app can reach Firestore.
  Future.microtask(() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.collectionTranscriptions)
          .limit(1)
          .get();
      debugPrint('Firestore connectivity test succeeded: retrieved ${snapshot.docs.length} docs');
    } catch (e) {
      debugPrint('Firestore connectivity test failed: $e');
    }
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch ThemeMode states
    final themeMode = ref.watch(themeNotifierProvider);

    return MaterialApp(
      title: 'Smart Transcription System',
      debugShowCheckedModeBanner: false,
      
      // Theme settings
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      
      // Launch Splash Screen
      home: const SplashScreen(),
    );
  }
}
