import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/extraction_model_controller.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/error_dialog.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../expenses/data/supabase_expense_repository.dart';
import '../../../expenses/domain/expense.dart';
import '../../../expenses/domain/expense_repository.dart';
import '../../../expenses/presentation/widgets/category_selector.dart';
import '../../data/supabase_extract_repository.dart';
import '../../domain/extracted_expense.dart';
import '../utils/dedup.dart';

enum _Phase { choosing, loading, review }

/// Importa spese da uno screenshot: scelta immagine -> estrazione (Claude
/// Vision via Edge Function) -> review editabile -> salvataggio in blocco
/// (vedi ARCHITECTURE.md - flow 2 e 3).
class ScreenshotImportScreen extends ConsumerStatefulWidget {
  const ScreenshotImportScreen({super.key, required this.budgetId});

  final String budgetId;

  @override
  ConsumerState<ScreenshotImportScreen> createState() => _ScreenshotImportScreenState();
}

class _ScreenshotImportScreenState extends ConsumerState<ScreenshotImportScreen> {
  final _formKey = GlobalKey<FormState>();

  _Phase _phase = _Phase.choosing;
  List<ExtractedExpense> _items = const [];
  int _excluded = 0;
  int _index = 0;
  bool _saving = false;

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(source: source);
    } catch (_) {
      if (!mounted) return;
      await showErrorDialog(
        context,
        source == ImageSource.camera
            ? 'Impossibile aprire la fotocamera su questo dispositivo.'
            : 'Impossibile aprire la galleria.',
      );
      return;
    }
    if (file == null) return;

    setState(() => _phase = _Phase.loading);
    try {
      final bytes = await file.readAsBytes();
      final categories = await ref.read(expenseCategoriesProvider(widget.budgetId).future);
      final model = ref.read(extractionModelControllerProvider);
      final extracted = await ref.read(extractRepositoryProvider).extract(
            bytes: bytes,
            mediaType: _mediaTypeFor(file),
            categories: categories,
            model: model,
            sourcePath: file.path,
          );
      final existing = await ref.read(recentExpensesProvider(widget.budgetId).future);
      final result = dedupExtracted(extracted, existing);
      if (!mounted) return;
      setState(() {
        _items = result.kept;
        _excluded = result.excluded;
        _index = 0;
        _phase = _Phase.review;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = _Phase.choosing);
      await showErrorDialog(context, errorMessage(e));
    }
  }

  String _mediaTypeFor(XFile file) {
    final mime = file.mimeType;
    if (mime != null && mime.startsWith('image/')) return mime;
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  void _removeCurrent() {
    setState(() {
      _items = [..._items]..removeAt(_index);
      if (_index >= _items.length && _index > 0) _index--;
    });
  }

  void _next() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_index < _items.length - 1) setState(() => _index++);
  }

  void _prev() {
    if (_index > 0) setState(() => _index--);
  }

  bool _isComplete(ExtractedExpense e) =>
      e.title.trim().isNotEmpty && e.amount > 0 && e.date != null && e.categoryId != null;

  Future<void> _save() async {
    if (_items.isEmpty) return;
    // Valida la voce visibile (mostra gli errori inline), poi assicurati che
    // tutte le altre siano complete: se non lo sono, salta alla prima incompleta.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final incomplete = _items.indexWhere((e) => !_isComplete(e));
    if (incomplete != -1) {
      setState(() => _index = incomplete);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa i campi obbligatori di questa voce')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final items = <NewExpense>[
        for (final e in _items)
          (
            title: e.title.trim(),
            amount: e.amount,
            date: e.date!,
            categoryId: e.categoryId!,
            subcategoryId: e.subcategoryId,
            type: e.type,
          ),
      ];
      await ref
          .read(expenseRepositoryProvider)
          .addExpenses(budgetId: widget.budgetId, items: items);
      ref.invalidate(recentExpensesProvider(widget.budgetId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length} voci salvate')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showErrorDialog(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importa da screenshot')),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.choosing => _ChoosingView(onPick: _pick),
          _Phase.loading => const _LoadingView(),
          _Phase.review => _buildReview(context),
        },
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                _excluded > 0
                    ? 'Tutte le voci rilevate ($_excluded) erano gia’ presenti nel budget.'
                    : 'Nessuna voce rilevata nell’immagine.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => setState(() => _phase = _Phase.choosing),
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    final current = _items[_index];
    final isLast = _index == _items.length - 1;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  if (_excluded > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ExcludedNotice(count: _excluded),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Spesa ${_index + 1} di ${_items.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Form(
                    key: _formKey,
                    child: _ReviewCard(
                      key: ObjectKey(current),
                      item: current,
                      budgetId: widget.budgetId,
                      onDelete: _removeCurrent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Row(
                children: [
                  if (_index > 0) ...[
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _prev,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Indietro'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: isLast
                        ? LoadingButton(
                            loading: _saving,
                            onPressed: _save,
                            child: Text('Salva ${_items.length} voci'),
                          )
                        : FilledButton(
                            onPressed: _next,
                            child: const Text('Avanti'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoosingView extends StatelessWidget {
  const _ChoosingView({required this.onPick});

  final ValueChanged<ImageSource> onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.document_scanner_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Scegli uno screenshot di spese o di un estratto conto: '
                'le voci verranno lette automaticamente e potrai rivederle prima di salvarle.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => onPick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Dalla galleria'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => onPick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Scatta una foto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Estrazione in corso…'),
        ],
      ),
    );
  }
}

class _ExcludedNotice extends StatelessWidget {
  const _ExcludedNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count == 1
                  ? '1 voce gia’ presente e’ stata esclusa.'
                  : '$count voci gia’ presenti sono state escluse.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card di una voce in review: titolo/importo/tipo/data + categoria.
/// `data` e `categoria` sono obbligatorie (validate dal Form del parent).
class _ReviewCard extends ConsumerStatefulWidget {
  const _ReviewCard({
    super.key,
    required this.item,
    required this.budgetId,
    required this.onDelete,
  });

  final ExtractedExpense item;
  final String budgetId;
  final VoidCallback onDelete;

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  late final TextEditingController _title;
  late final TextEditingController _amount;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item.title);
    _amount = TextEditingController(
      text: widget.item.amount > 0 ? widget.item.amount.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final categories = ref.watch(expenseCategoriesProvider(widget.budgetId)).value ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Elimina voce',
                onPressed: widget.onDelete,
              ),
            ),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Titolo'),
              onChanged: (v) => item.title = v,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Inserisci un titolo' : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Importo', prefixText: '€ '),
                    onChanged: (v) {
                      final parsed = parseAmount(v);
                      if (parsed != null) item.amount = parsed;
                    },
                    validator: (v) {
                      final parsed = parseAmount(v ?? '');
                      if (parsed == null || parsed <= 0) return 'Importo non valido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FormField<DateTime>(
                    initialValue: item.date,
                    validator: (v) => v == null ? 'Manca la data' : null,
                    builder: (field) => InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: item.date ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        item.date = picked;
                        field.didChange(picked);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Data',
                          errorText: field.errorText,
                        ),
                        child: Text(
                          field.value != null ? formatDate(field.value!) : 'gg/mm/aaaa',
                          style: TextStyle(
                            color: field.value != null
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ExpenseType>(
              segments: const [
                ButtonSegment(value: ExpenseType.expense, label: Text('Uscita')),
                ButtonSegment(value: ExpenseType.income, label: Text('Entrata')),
              ],
              selected: {item.type},
              onSelectionChanged: (s) => setState(() => item.type = s.first),
            ),
            const SizedBox(height: 12),
            CategorySelector(
              budgetId: widget.budgetId,
              categories: categories,
              categoryId: item.categoryId,
              subcategoryId: item.subcategoryId,
              onCategoryChanged: (v) => setState(() {
                item.categoryId = v;
                item.subcategoryId = null;
              }),
              onSubcategoryChanged: (v) => setState(() => item.subcategoryId = v),
            ),
          ],
        ),
      ),
    );
  }
}
