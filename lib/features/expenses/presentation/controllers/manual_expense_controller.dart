import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../budget/data/supabase_budget_repository.dart';
import '../../data/supabase_expense_repository.dart';

/// Stato del salvataggio di una nuova spesa manuale (vedi ARCHITECTURE.md - flow 4).
class ManualExpenseController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> addExpense({
    required String title,
    required double amount,
    required DateTime date,
    required String categoryId,
    String? subcategoryId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final budget = await ref.read(currentBudgetProvider.future);
      await ref.read(expenseRepositoryProvider).addExpense(
            budgetId: budget!.id,
            title: title,
            amount: amount,
            date: date,
            categoryId: categoryId,
            subcategoryId: subcategoryId,
          );
    });
    if (!state.hasError) {
      ref.invalidate(recentExpensesProvider);
    }
  }

  Future<void> addSpreadExpenses({
    required String title,
    required double amount,
    required DateTime startMonth,
    required DateTime endMonth,
    required String categoryId,
    String? subcategoryId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final budget = await ref.read(currentBudgetProvider.future);
      await ref.read(expenseRepositoryProvider).addSpreadExpenses(
            budgetId: budget!.id,
            title: title,
            amount: amount,
            startMonth: startMonth,
            endMonth: endMonth,
            categoryId: categoryId,
            subcategoryId: subcategoryId,
          );
    });
    if (!state.hasError) {
      ref.invalidate(recentExpensesProvider);
    }
  }
}

final manualExpenseControllerProvider =
    AsyncNotifierProvider<ManualExpenseController, void>(ManualExpenseController.new);
