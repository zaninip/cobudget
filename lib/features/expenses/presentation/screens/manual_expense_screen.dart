import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/error_dialog.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../data/supabase_expense_repository.dart';
import '../../domain/category.dart';
import '../controllers/manual_expense_controller.dart';
import '../widgets/category_selector.dart';
import '../widgets/month_selector.dart';

/// Form di inserimento manuale di una spesa, con toggle "spalma su più mesi"
/// (vedi ARCHITECTURE.md - flow 4, UI_DESIGN.md - sezione 5).
class ManualExpenseScreen extends ConsumerStatefulWidget {
  const ManualExpenseScreen({super.key, required this.budgetId});

  final String budgetId;

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

  int get _spreadMonthsCount =>
      (_endMonth.year - _startMonth.year) * 12 + (_endMonth.month - _startMonth.month) + 1;

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
    if (_spreadEnabled && _spreadMonthsCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Il mese di fine deve essere successivo o uguale a quello di inizio'),
        ),
      );
      return;
    }

    final title = _titleController.text.trim();
    final amount = parseAmount(_amountController.text)!;
    final controller = ref.read(manualExpenseControllerProvider.notifier);

    if (_spreadEnabled) {
      controller.addSpreadExpenses(
        budgetId: widget.budgetId,
        title: title,
        amount: amount,
        startMonth: _startMonth,
        endMonth: _endMonth,
        categoryId: _categoryId!,
        subcategoryId: _subcategoryId,
      );
    } else {
      controller.addExpense(
        budgetId: widget.budgetId,
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
    final categoriesAsync = ref.watch(expenseCategoriesProvider(widget.budgetId));
    final saveState = ref.watch(manualExpenseControllerProvider);

    ref.listen<AsyncValue<void>>(manualExpenseControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          showErrorDialog(context, errorMessage(error));
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
              final amount = parseAmount(value ?? '');
              if (amount == null || amount <= 0) return 'Inserisci un importo valido';
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (!_spreadEnabled)
            Card(
              child: ListTile(
                title: const Text('Data'),
                subtitle: Text(formatDate(_date)),
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
          CategorySelector(
            budgetId: widget.budgetId,
            categories: categories,
            categoryId: _categoryId,
            subcategoryId: _subcategoryId,
            onCategoryChanged: (value) => setState(() {
              _categoryId = value;
              _subcategoryId = null;
            }),
            onSubcategoryChanged: (value) => setState(() => _subcategoryId = value),
          ),
          const SizedBox(height: 24),
          LoadingButton(
            loading: isSaving,
            onPressed: _save,
            child: const Text('Salva'),
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
