import 'package:flutter/material.dart';

/// A drop-in replacement for [Scaffold] that paints the shared galaxy
/// background behind all app screens, keeping the visual language
/// consistent with the Dashboard.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.extendBody = false,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final bool extendBody;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: extendBody,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: _GalaxyBackground()),
          Positioned.fill(child: body),
        ],
      ),
    );
  }
}

class _GalaxyBackground extends StatelessWidget {
  const _GalaxyBackground();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF0F1115)),
          Image.asset(
            'assets/images/galaxy.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.40),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.50),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: Image.asset(
                'assets/noise.png',
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
