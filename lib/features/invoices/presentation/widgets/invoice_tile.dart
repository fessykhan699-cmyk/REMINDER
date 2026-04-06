import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/invoice.dart';
import 'invoice_status_badge.dart';

class InvoiceTile extends StatelessWidget {
  const InvoiceTile({super.key, required this.invoice, required this.onTap});

  final Invoice invoice;
  final VoidCallback onTap;

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
          child: Padding(
            padding: appCardPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.clientName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: spacingXS),
                      Text(
                        invoice.service,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: spacingSM),
                      Text(
                        'Due ${AppFormatters.shortDate(invoice.dueDate)}',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: spacingMD),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppFormatters.currency(
                        invoice.amount,
                        currencyCode: invoice.currencyCode,
                      ),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: spacingSM),
                    InvoiceStatusBadge(status: invoice.status),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
