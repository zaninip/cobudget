import 'package:flutter/material.dart';

import '../../domain/category.dart';
import '../../domain/tag.dart';

/// Card dei filtri condivisa tra la pagina di riepilogo (grafici) e la home del
/// budget: categorie, sottocategorie (limitate alle categorie scelte), tag e il
/// filtro "Escludi spese straordinarie".
///
/// La sezione del periodo (dropdown + date personalizzate) è specifica della
/// pagina grafici e viene passata via [periodSection]: nella home è `null`, così
/// l'aspetto resta identico ma senza filtro temporale.
class ExpenseFiltersCard extends StatelessWidget {
  const ExpenseFiltersCard({
    super.key,
    required this.categories,
    required this.tags,
    required this.categoryIds,
    required this.subcategoryIds,
    required this.tagIds,
    required this.onToggleCategory,
    required this.onToggleSubcategory,
    required this.onToggleTag,
    required this.excludeExceptional,
    required this.onExcludeExceptionalChanged,
    this.periodSection,
  });

  final List<ExpenseCategory> categories;
  final List<Tag> tags;
  final Set<String> categoryIds;
  final Set<String> subcategoryIds;
  final Set<String> tagIds;
  final ValueChanged<String> onToggleCategory;
  final ValueChanged<String> onToggleSubcategory;
  final ValueChanged<String> onToggleTag;
  final bool excludeExceptional;
  final ValueChanged<bool> onExcludeExceptionalChanged;

  /// Sezione periodo mostrata in cima alla card (solo pagina grafici).
  final Widget? periodSection;

  @override
  Widget build(BuildContext context) {
    final subOptions = <Subcategory>[
      for (final c in categories)
        if (categoryIds.contains(c.id)) ...c.subcategories,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (periodSection != null) ...[
              periodSection!,
              const SizedBox(height: 14),
            ],
            FilterChipsGroup(
              label: 'Categorie',
              options: [for (final c in categories) (id: c.id, name: c.name)],
              selected: categoryIds,
              onToggle: onToggleCategory,
            ),
            if (subOptions.isNotEmpty) ...[
              const SizedBox(height: 8),
              FilterChipsGroup(
                label: 'Sottocategorie',
                options: [for (final s in subOptions) (id: s.id, name: s.name)],
                selected: subcategoryIds,
                onToggle: onToggleSubcategory,
              ),
            ],
            const SizedBox(height: 12),
            // Il filtro Tag c'è sempre (menù a tendina a selezione multipla);
            // se non ci sono ancora tag, il campo lo segnala ed è disabilitato.
            TagFilterMenu(
              tags: tags,
              selected: tagIds,
              onToggle: onToggleTag,
            ),
            const SizedBox(height: 4),
            _ExcludeExceptionalRow(
              value: excludeExceptional,
              onChanged: onExcludeExceptionalChanged,
            ),
          ],
        ),
      ),
    );
  }
}

typedef ChipOption = ({String id, String name});

/// Gruppo di chip a selezione multipla (vuoto = "Tutte").
class FilterChipsGroup extends StatelessWidget {
  const FilterChipsGroup({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String label;
  final List<ChipOption> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final o in options)
              FilterChip(
                label: Text(o.name),
                selected: selected.contains(o.id),
                onSelected: (_) => onToggle(o.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// Filtro Tag come menù a tendina a selezione multipla (checkbox). Selezione
/// vuota = "Tutte"; semantica OR coerente con il resto dei filtri. Se non ci
/// sono tag nel budget, il campo è disabilitato e lo segnala.
class TagFilterMenu extends StatelessWidget {
  const TagFilterMenu({
    super.key,
    required this.tags,
    required this.selected,
    required this.onToggle,
  });

  final List<Tag> tags;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = tags.isEmpty;
    final selectedNames =
        tags.where((t) => selected.contains(t.id)).map((t) => t.name).toList();
    final text = empty
        ? 'Nessuna tag ancora'
        : selectedNames.isEmpty
            ? 'Tutte'
            : selectedNames.join(', ');
    final muted = empty || selectedNames.isEmpty;

    Widget field(VoidCallback? onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Tag', isDense: true),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
                      fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        );

    if (empty) return field(null);

    return MenuAnchor(
      menuChildren: [
        for (final t in tags)
          SizedBox(
            width: 260,
            child: CheckboxListTile(
              value: selected.contains(t.id),
              onChanged: (_) => onToggle(t.id),
              title: Text(t.name),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
      ],
      builder: (context, controller, _) => field(
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// Riga compatta con la checkbox "Escludi spese straordinarie".
class _ExcludeExceptionalRow extends StatelessWidget {
  const _ExcludeExceptionalRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Escludi spese straordinarie',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
