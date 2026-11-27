import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../core/theme/app_design_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_logo.dart';
import 'auth_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Timer? _navigateTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _controller.forward();
    _navigateToNext();
  }

  @override
  void dispose() {
    _navigateTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Check auth session and navigate
  void _navigateToNext() {
    _navigateTimer = Timer(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;

      final authService = ref.read(authServiceProvider);
      var user = authService.currentUser;

      if (user == null) {
        try {
          user = await authService.authStateChanges.first.timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () => null,
          );
        } catch (_) {}
      }

      if (!mounted) return;

      final targetScreen = user != null ? const DashboardScreen() : const AuthScreen();

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: tokens.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: tokens.background,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated App Logo
            ScaleTransition(
              scale: _scaleAnimation,
              child: const AppLogo(
                height: 96,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: tokens.spaceXl),

            // App Brand Name
            Text(
              config.branding.appName,
              style: TextStyle(
                fontSize: tokens.fontDisplay,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: tokens.textPrimary,
              ),
            ),
            SizedBox(height: tokens.spaceSm),

            // App Subtitle
            Text(
              'Real-Time Speech Transcription',
              style: TextStyle(
                fontSize: tokens.fontMd,
                color: tokens.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: tokens.spaceXxl),

            // Loading indicator
            SizedBox(
              width: tokens.spaceXl,
              height: tokens.spaceXl,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(tokens.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
