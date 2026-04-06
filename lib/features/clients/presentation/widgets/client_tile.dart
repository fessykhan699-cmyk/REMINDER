import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/client.dart';

class ClientTile extends StatelessWidget {
  const ClientTile({
    super.key,
    required this.client,
    required this.onTap,
    this.onLongPress,
  });

  final Client client;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: appCardMargin,
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(cardRadius),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: appCardPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.30),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    client.name.isEmpty
                        ? '?'
                        : client.name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: spacingXS),
                      if (client.email.isNotEmpty)
                        Text(
                          client.email,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (client.phone.isNotEmpty) ...[
                        const SizedBox(height: spacingXS),
                        Text(
                          client.phone,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (client.email.isEmpty && client.phone.isEmpty)
                        const Text(
                          'No contact details',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: spacingSM),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
