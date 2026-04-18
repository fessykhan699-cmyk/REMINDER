import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';
import '../../domain/entities/subscription_state.dart';

import '../../../../data/services/analytics_service.dart';

Future<bool> promptUpgradeForDecision(
  BuildContext context,
  SubscriptionGateDecision decision,
) async {
  if (!context.mounted) return false;
  
  // Log the tap/prompt from the gate
  final source = decision.feature.name;
  AnalyticsService.instance.logUpgradeTapped('gate_$source');
  
  final upgraded = await const UpgradeToProRoute().push<bool>(context);
  return upgraded == true;
}

