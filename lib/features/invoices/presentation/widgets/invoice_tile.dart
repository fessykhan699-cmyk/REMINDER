import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/components/glass_card.dart';
import '../../domain/entities/invoice.dart';
import 'invoice_status_badge.dart';

class InvoiceTile extends StatelessWidget {
  const InvoiceTile({super.key, required this.invoice, required this.onTap});

  final Invoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: appCardMargin,
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: appCardPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar circle — matches dashboard _PriorityInvoiceRow
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.14),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.30),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      invoice.clientName.isEmpty
                          ? '?'
                          : invoice.clientName.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                invoice.clientName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            if (invoice.isRecurring) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.sync_rounded,
                                size: 14,
                                color: AppColors.accent,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invoice.items.length > 1
                              ? '${invoice.items.length} Items'
                              : invoice.items.isNotEmpty
                                  ? invoice.items.first.description
                                  : invoice.service,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Due ${AppFormatters.shortDate(invoice.dueDate)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        if (invoice.recurringParentId != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Recurring Draft',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: spacingSM),
                      InvoiceStatusBadge(status: invoice.status),
                      if (invoice.totalPaid > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          invoice.isFullyPaid
                              ? 'Fully Paid'
                              : 'Paid: ${AppFormatters.currency(invoice.totalPaid, currencyCode: invoice.currencyCode)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
