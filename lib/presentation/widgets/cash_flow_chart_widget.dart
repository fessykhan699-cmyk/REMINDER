import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/cash_flow_service.dart';
import '../../../features/settings/presentation/controllers/app_preferences_controller.dart';

class CashFlowChartWidget extends ConsumerWidget {
  final List<MonthlyCashFlow> data;

  const CashFlowChartWidget({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final currencyCode = ref.watch(appPreferencesControllerProvider).valueOrNull?.defaultCurrency ?? 'USD';

      // If all values are zero: show a centered Text widget instead
      bool allZero = data.every((d) => d.totalPaid == 0);
      if (allZero) {
        return const Center(
          child: Text(
            'No paid invoices in the last 6 months',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        );
      }

      return SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: _getMaxY(),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.backgroundSecondary,
                tooltipBorder: const BorderSide(color: AppColors.accent, width: 1),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final monthData = data[groupIndex];
                  return BarTooltipItem(
                    '${monthData.label}\n',
                    const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: AppFormatters.currency(
                          monthData.totalPaid,
                          currencyCode: currencyCode,
                        ),
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          data[index].label,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: data.asMap().entries.map((entry) {
              final index = entry.key;
              final monthData = entry.value;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: monthData.totalPaid,
                    color: AppColors.accent,
                    width: 16,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      );
    } catch (e) {
      return const Center(
        child: Text(
          'Chart unavailable',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
  }

  double _getMaxY() {
    double maxTotal = data.fold(0.0, (max, d) => d.totalPaid > max ? d.totalPaid : max);
    if (maxTotal == 0) return 100;
    return maxTotal * 1.2; // Give 20% breathing room
  }
}
