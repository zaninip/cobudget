import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase_expense_repository.dart';
import '../../domain/tag.dart';

/// Selettore di tag a testo libero (relazione N-a-N): mostra le tag scelte come
/// chip rimovibili, un campo per aggiungerne e i suggerimenti (chip tappabili)
/// dalle tag già esistenti nel budget (`tagsProvider`).
///
/// Lo stato selezionato è controllato dal chiamante via [selectedNames]/[onChanged]:
/// vengono scambiati i NOMI (non gli id) perché in fase di inserimento si possono
/// creare tag che ancora non esistono. La deduplica è case-insensitive.
///
/// Robustezza: il testo digitato ma non ancora confermato (niente "+"/invio) viene
/// **committato automaticamente** quando si tocca fuori dal campo — incluso il
/// bottone Salva, perché `onTapOutside` scatta sul tocco prima dell'azione del
/// bottone. Così la tag non va persa anche se l'utente non preme invio.
class TagSelector extends ConsumerStatefulWidget {
  const TagSelector({
    super.key,
    required this.budgetId,
    required this.selectedNames,
    required this.onChanged,
  });

  final String budgetId;
  final List<String> selectedNames;
  final ValueChanged<List<String>> onChanged;

  @override
  ConsumerState<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends ConsumerState<TagSelector> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final name = raw.trim();
    if (name.isNotEmpty) {
      final lower = name.toLowerCase();
      if (!widget.selectedNames.any((t) => t.toLowerCase() == lower)) {
        widget.onChanged([...widget.selectedNames, name]);
      }
    }
    _controller.clear();
    setState(() {});
  }

  /// Conferma il testo eventualmente ancora nel campo (senza "+"/invio).
  void _commitPending() {
    if (_controller.text.trim().isNotEmpty) _add(_controller.text);
  }

  void _remove(String name) {
    widget.onChanged([...widget.selectedNames]..remove(name));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tags = ref.watch(tagsProvider(widget.budgetId)).value ?? const <Tag>[];
    final selectedLower = widget.selectedNames.map((e) => e.toLowerCase()).toSet();
    final query = _controller.text.trim().toLowerCase();
    final suggestions = [
      for (final t in tags)
        if (!selectedLower.contains(t.name.toLowerCase()) &&
            (query.isEmpty || t.name.toLowerCase().contains(query)))
          t.name,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tag',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        if (widget.selectedNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final name in widget.selectedNames)
                Chip(
                  label: Text(name),
                  onDeleted: () => _remove(name),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Aggiungi tag',
            hintText: 'Scrivi e premi +',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Aggiungi tag',
              onPressed: () => _add(_controller.text),
            ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: _add,
          // Conferma il testo pendente quando si tocca fuori (es. il bottone Salva).
          onTapOutside: (_) {
            _commitPending();
            _focusNode.unfocus();
          },
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final name in suggestions.take(12))
                ActionChip(
                  label: Text(name),
                  onPressed: () => _add(name),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
