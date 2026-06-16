import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/amount_text.dart';
import '../utils/category_visuals.dart';
import '../utils/expense_summary.dart';

/// Colore di visualizzazione di una fetta. Quando [shaded] è attivo (ripartizione
/// per sottocategoria, che condividono il colore della categoria madre) genera
/// varianti di luminosità per distinguere le fette; le fette senza colore
/// ([CategorySlice.colorHex] null) usano il [neutral].
Color summarySliceColor(
  CategorySlice slice,
  int index,
  int count, {
  required bool shaded,
  required Color neutral,
}) {
  final hex = slice.colorHex;
  if (hex == null) return neutral;
  final base = categoryColor(hex);
  if (!shaded || count <= 1) return base;

  final hsl = HSLColor.fromColor(base);
  const span = 0.34;
  final start = (hsl.lightness - span / 2).clamp(0.22, 0.7);
  final lightness = (start + span * index / (count - 1)).clamp(0.18, 0.82);
  return hsl.withLightness(lightness).toColor();
}

/// Grafico a ciambella della ripartizione per categoria/sottocategoria.
class SummaryPieChart extends StatefulWidget {
  const SummaryPieChart({
    super.key,
    required this.slices,
    required this.total,
    required this.shaded,
  });

  final List<CategorySlice> slices;
  final double total;
  final bool shaded;

  @override
  State<SummaryPieChart> createState() => _SummaryPieChartState();
}

class _SummaryPieChartState extends State<SummaryPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final neutral = scheme.onSurfaceVariant;
    final count = widget.slices.length;
    final touched = _touchedIndex >= 0 && _touchedIndex < count
        ? widget.slices[_touchedIndex]
        : null;

    return Column(
      children: [
        // Riga info: la fetta sotto il cursore (nome+valore) o il totale.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                touched?.label ?? 'Totale',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: neutral),
              ),
            ),
            const SizedBox(width: 8),
            AmountText(touched?.amount ?? widget.total, fontSize: 16),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 0,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response?.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex = response!.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sections: [
                for (var i = 0; i < count; i++)
                  _section(i, widget.slices[i], neutral),
              ],
            ),
          ),
        ),
      ],
    );
  }

  PieChartSectionData _section(int index, CategorySlice slice, Color neutral) {
    final touched = index == _touchedIndex;
    final color = summarySliceColor(
      slice,
      index,
      widget.slices.length,
      shaded: widget.shaded,
      neutral: neutral,
    );
    final percent = slice.percentOf(widget.total);

    return PieChartSectionData(
      value: slice.amount,
      color: color,
      radius: touched ? 108 : 100,
      titlePositionPercentageOffset: 0.6,
      title: percent >= 8 ? '${percent.round()}%' : '',
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }
}
