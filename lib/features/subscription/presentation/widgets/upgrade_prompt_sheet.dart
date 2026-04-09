import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';
import '../../domain/entities/subscription_state.dart';

Future<bool> promptUpgradeForDecision(
  BuildContext context,
  SubscriptionGateDecision decision,
) async {
  if (!context.mounted) return false;
  final upgraded = await const UpgradeToProRoute().push<bool>(context);
  return upgraded == true;
}

