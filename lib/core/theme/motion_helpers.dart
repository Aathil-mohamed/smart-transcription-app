import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Smooth, spring-like vertical slide route for bottom sheet / modal style screens.
class SlideUpRoute<T> extends PageRouteBuilder<T> {
  SlideUpRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (c, _, __) => builder(c),
          transitionsBuilder: (_, anim, __, child) {
            final curve = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutExpo,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(curve),
                child: child,
              ),
            );
          },
        );
}

/// Tactile interactive container with haptic feedback and fluid press scale.
class Tactile extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final HitTestBehavior behavior;

  const Tactile({
    super.key,
    required this.child,
    this.onTap,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<Tactile> createState() => _TactileState();
}

class _TactileState extends State<Tactile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _down = false);
              HapticFeedback.lightImpact();
              widget.onTap?.call();
            },
      onTapCancel: widget.onTap == null ? null : () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
