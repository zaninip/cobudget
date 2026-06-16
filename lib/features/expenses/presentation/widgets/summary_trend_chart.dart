import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../utils/expense_summary.dart';

/// Grafico a barre raggruppate dell'andamento nel tempo: uscite (viola) ed
/// entrate (verde) affiancate per bucket, con serie opzionale del saldo (teal).
class SummaryTrendChart extends StatelessWidget {
  const SummaryTrendChart({
    super.key,
    required this.buckets,
    required this.showOutcome,
    required this.showIncome,
    required this.showBalance,
  });

  final List<PeriodBucket> buckets;
  final bool showOutcome;
  final bool showIncome;
  final bool showBalance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outcomeColor = scheme.primary;
    final incomeColor = context.appColors.success;
    final balanceColor = scheme.secondary;

    // Estremi dell'asse Y (il saldo può essere negativo).
    var maxY = 0.0;
    var minY = 0.0;
    for (final b in buckets) {
      maxY = [
        maxY,
        if (showOutcome) b.outcome,
        if (showIncome) b.income,
        if (showBalance) b.balance,
      ].reduce((a, c) => a > c ? a : c);
      if (showBalance && b.balance < minY) minY = b.balance;
    }
    if (maxY == 0 && minY == 0) maxY = 1;
    maxY = _niceCeil(maxY);
    minY = minY == 0 ? 0 : -_niceCeil(minY.abs());
    final interval = _niceStep(maxY - minY);

    final seriesCount = (showOutcome ? 1 : 0) + (showIncome ? 1 : 0) + (showBalance ? 1 : 0);
    final perGroup = 24.0 + seriesCount * 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (buckets.length * perGroup).clamp(constraints.maxWidth, double.infinity);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width.toDouble(),
            height: 260,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  minY: minY,
                  groupsSpace: 12,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => scheme.surfaceContainerHighest,
                      tooltipBorder: BorderSide(color: scheme.outline),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                        formatCurrency(rod.toY),
                        TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: scheme.outline.withValues(alpha: 0.5), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              _compact(value),
                              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              buckets[i].label,
                              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < buckets.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 3,
                        barRods: [
                          if (showOutcome) _rod(buckets[i].outcome, outcomeColor),
                          if (showIncome) _rod(buckets[i].income, incomeColor),
                          if (showBalance) _rod(buckets[i].balance, balanceColor),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  BarChartRodData _rod(double value, Color color) => BarChartRodData(
        toY: value,
        color: color,
        width: 10,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      );

  static String _compact(double v) {
    final a = v.abs();
    if (a >= 1000) return '${(v / 1000).toStringAsFixed(a >= 10000 ? 0 : 1)}k';
    return v.toStringAsFixed(0);
  }

  /// Arrotonda per eccesso a un valore "tondo" leggibile per l'asse.
  static double _niceCeil(double v) {
    if (v <= 0) return 0;
    final magnitude = _pow10((v.toString().split('.').first.length - 1).clamp(0, 12));
    return (v / magnitude).ceil() * magnitude;
  }

  static double _niceStep(double span) {
    if (span <= 0) return 1;
    final raw = span / 4;
    final magnitude = _pow10(raw.floor().toString().length - 1);
    final normalized = raw / magnitude;
    final step = normalized <= 1 ? 1 : (normalized <= 2 ? 2 : (normalized <= 5 ? 5 : 10));
    return step * magnitude;
  }

  static double _pow10(int exp) {
    var result = 1.0;
    for (var i = 0; i < exp; i++) {
      result *= 10;
    }
    return result;
  }
}
