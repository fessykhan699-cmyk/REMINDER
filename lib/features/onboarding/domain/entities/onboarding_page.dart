import 'package:flutter/material.dart';

class OnboardingPageEntity {
  const OnboardingPageEntity({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String cta;
  final IconData icon;
}
