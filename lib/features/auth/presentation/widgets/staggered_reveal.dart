import 'package:flutter/material.dart';

class StaggeredReveal extends StatelessWidget {
  const StaggeredReveal({
    super.key,
    required this.controller,
    required this.begin,
    required this.end,
    required this.child,
    this.offsetY = 18,
  });

  final Animation<double> controller;
  final double begin;
  final double end;
  final Widget child;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, stableChild) {
        final raw = ((controller.value - begin) / (end - begin)).clamp(
          0.0,
          1.0,
        );
        final eased = Curves.easeInOut.transform(raw);

        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * offsetY),
            child: stableChild,
          ),
        );
      },
    );
  }
}
