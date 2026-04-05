import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
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
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.30)),
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
        title: Text(
          client.name,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (client.email.isNotEmpty)
              Text(
                client.email,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            if (client.phone.isNotEmpty)
              Text(
                client.phone,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            if (client.email.isEmpty && client.phone.isEmpty)
              const Text(
                'No contact details',
                style: TextStyle(color: AppColors.textSecondary),
              ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: AppColors.textMuted),
      ),
    );
  }
}
