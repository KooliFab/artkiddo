import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Highlights the newly-added artwork card once after returning from
/// capture. Fades an accent surface halo over 1200ms, or — under
/// reduced motion — a static 2px accent border for the same duration.
class HighlightOnce extends StatefulWidget {
  final bool active;
  final Widget child;
  final BorderRadius borderRadius;

  const HighlightOnce({
    super.key,
    required this.active,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.lg)),
  });

  @override
  State<HighlightOnce> createState() => _HighlightOnceState();
}

class _HighlightOnceState extends State<HighlightOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.highlight,
    );
    if (widget.active) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant HighlightOnce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final finished = t >= 1.0;
        if (finished) return widget.child;

        final opacity = reduceMotion ? 1.0 : (1.0 - t);
        return Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: AppColors.accent.withValues(
                alpha: reduceMotion ? 1.0 : opacity,
              ),
              width: 2,
            ),
            boxShadow: reduceMotion
                ? const []
                : [
                    BoxShadow(
                      color: AppColors.accentSurface.withValues(
                        alpha: opacity * 0.9,
                      ),
                      blurRadius: 12,
                    ),
                  ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
