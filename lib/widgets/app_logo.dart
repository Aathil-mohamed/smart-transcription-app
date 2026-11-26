import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';

/// Reusable application logo widget that resolves its asset paths from
/// [appConfigProvider] and adjusts for light/dark theme brightness.
class AppLogo extends ConsumerWidget {
  final double? size;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Brightness? brightness;

  const AppLogo({
    super.key,
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.brightness,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final effectiveBrightness = brightness ?? Theme.of(context).brightness;
    final isDark = effectiveBrightness == Brightness.dark;

    final assetPath = isDark
        ? config.branding.logoWhite
        : config.branding.logoBlack;

    return Image.asset(
      assetPath,
      width: width ?? size,
      height: height ?? size,
      fit: fit,
      semanticLabel: config.branding.appName,
    );
  }
}
