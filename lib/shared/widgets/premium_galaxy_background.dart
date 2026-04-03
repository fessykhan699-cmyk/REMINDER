import 'package:flutter/material.dart';

class PremiumGalaxyBackground extends StatelessWidget {
  const PremiumGalaxyBackground({super.key, this.galaxyOpacity = 0.30});

  final double galaxyOpacity;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF0F1115)),
          Positioned.fill(
            child: Opacity(
              opacity: galaxyOpacity,
              child: Image.asset('assets/images/galaxy.jpg', fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0xCC0F1115),
                    Color(0xFF0F1115),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
