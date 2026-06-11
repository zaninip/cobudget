import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/supabase_expense_repository.dart';
import '../../domain/category.dart';
import '../controllers/manual_expense_controller.dart';
import '../utils/category_visuals.dart';
import '../widgets/month_selector.dart';
import '../widgets/new_category_dialog.dart';
import '../widgets/new_subcategory_dialog.dart';

/// Form di inserimento manuale di una spesa, con toggle "spalma su più mesi"
/// (vedi ARCHITECTURE.md - flow 4, UI_DESIGN.md - sezione 5).
class ManualExpenseScreen extends ConsumerStatefulWidget {
  const ManualExpenseScreen({super.key});

  @override
  ConsumerState<ManualExpenseScreen> createState() => _ManualExpenseScreenState();
}

class _ManualExpenseScreenState extends ConsumerState<ManualExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _date = DateTime.now();
  bool _spreadEnabled = false;
  late DateTime _startMonth = DateTime(_date.year, _date.month);
  late DateTime _endMonth = DateTime(_date.year, _date.month);

  String? _categoryId;
  String? _subcategoryId;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onTitleChanged() => setState(() {});

  double? _parseAmount(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  int get _spreadMonthsCount =>
      (_endMonth.year - _startMonth.year) * 12 + (_endMonth.month - _startMonth.month) + 1;

  String _errorMessage(Object error) {
    if (error is PostgrestException) return error.message;
    return 'Si è verificato un errore. Riprova.';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _addCategory() async {
    final category = await showDialog<ExpenseCategory>(
      context: context,
      builder: (context) => const NewCategoryDialog(),
    );
    if (category == null) return;
    setState(() {
      _categoryId = category.id;
      _subcategoryId = null;
    });
  }

  Future<void> _addSubcategory(String categoryId) async {
    final subcategory = await showDialog<Subcategory>(
      context: context,
      builder: (context) => NewSubcategoryDialog(categoryId: categoryId),
    );
    if (subcategory == null) return;
    setState(() => _subcategoryId = subcategory.id);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona una categoria')),
      );
      return;
    }
    if (_spreadEnabled && _spreadMonthsCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Il mese di fine deve essere successivo o uguale a quello di inizio'),
        ),
      );
      return;
    }

    final title = _titleController.text.trim();
    final amount = _parseAmount(_amountController.text)!;
    final controller = ref.read(manualExpenseControllerProvider.notifier);

    if (_spreadEnabled) {
      controller.addSpreadExpenses(
        title: title,
        amount: amount,
        startMonth: _startMonth,
        endMonth: _endMonth,
        categoryId: _categoryId!,
        subcategoryId: _subcategoryId,
      );
    } else {
      controller.addExpense(
        title: title,
        amount: amount,
        date: _date,
        categoryId: _categoryId!,
        subcategoryId: _subcategoryId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final saveState = ref.watch(manualExpenseControllerProvider);

    ref.listen<AsyncValue<void>>(manualExpenseControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
        },
      );
      if (previous is AsyncLoading && next is AsyncData) {
        context.pop();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Nuova spesa')),
      body: categoriesAsync.when(
        data: (categories) => _buildForm(context, categories, saveState.isLoading),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Errore nel caricamento delle categorie: $error')),
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<ExpenseCategory> categories, bool isSaving) {
    ExpenseCategory? selectedCategory;
    for (final category in categories) {
      if (category.id == _categoryId) {
        selectedCategory = category;
        break;
      }
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Titolo'),
            textCapitalization: TextCapitalization.sentences,
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Inserisci un titolo' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: 'Importo', prefixText: '€ '),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final amount = _parseAmount(value ?? '');
              if (amount == null || amount <= 0) return 'Inserisci un importo valido';
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (!_spreadEnabled)
            Card(
              child: ListTile(
                title: const Text('Data'),
                subtitle: Text(_formatDate(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
            ),
          SwitchListTile(
            title: const Text('Spalma su più mesi'),
            value: _spreadEnabled,
            onChanged: (value) => setState(() => _spreadEnabled = value),
          ),
          if (_spreadEnabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: MonthSelector(
                    label: 'Da',
                    value: _startMonth,
                    onChanged: (month) => setState(() {
                      _startMonth = month;
                      if (_endMonth.isBefore(_startMonth)) _endMonth = _startMonth;
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MonthSelector(
                    label: 'A',
                    value: _endMonth,
                    onChanged: (month) => setState(() => _endMonth = month),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSpreadPreview(),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Row(
                          children: [
                            Icon(categoryIcon(category.icon), color: categoryColor(category.color), size: 20),
                            const SizedBox(width: 8),
                            Text(category.name),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _categoryId = value;
                    _subcategoryId = null;
                  }),
                  validator: (value) => value == null ? 'Seleziona una categoria' : null,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Nuova categoria',
                onPressed: _addCategory,
              ),
            ],
          ),
          if (selectedCategory != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey(_categoryId),
                    initialValue: _subcategoryId,
                    decoration: const InputDecoration(labelText: 'Sottocategoria'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Nessuna')),
                      for (final subcategory in selectedCategory.subcategories)
                        DropdownMenuItem(value: subcategory.id, child: Text(subcategory.name)),
                    ],
                    onChanged: (value) => setState(() => _subcategoryId = value),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Nuova sottocategoria',
                  onPressed: () => _addSubcategory(selectedCategory!.id),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: isSaving ? null : _save,
            child: isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadPreview() {
    final n = _spreadMonthsCount;
    if (n < 1) {
      return Text(
        'Il mese di fine deve essere successivo o uguale a quello di inizio',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    final title = _titleController.text.trim();
    final displayTitle = title.isEmpty ? 'Titolo' : title;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('→ $n rate:', style: Theme.of(context).textTheme.bodyMedium),
            for (var i = 1; i <= n; i++) Text('$displayTitle $i/$n'),
          ],
        ),
      ),
    );
  }
}
