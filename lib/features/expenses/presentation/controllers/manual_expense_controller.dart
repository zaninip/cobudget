import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase_expense_repository.dart';
import '../../domain/expense.dart';

/// Stato del salvataggio di una nuova spesa manuale (vedi ARCHITECTURE.md - flow 4).
class ManualExpenseController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> addExpense({
    required String budgetId,
    required String title,
    required double amount,
    required DateTime date,
    required String categoryId,
    String? subcategoryId,
    ExpenseType type = ExpenseType.expense,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(expenseRepositoryProvider).addExpense(
            budgetId: budgetId,
            title: title,
            amount: amount,
            date: date,
            categoryId: categoryId,
            subcategoryId: subcategoryId,
            type: type,
          );
    });
    if (!state.hasError) {
      ref.invalidate(recentExpensesProvider(budgetId));
    }
  }

  Future<void> addSpreadExpenses({
    required String budgetId,
    required String title,
    required double amount,
    required DateTime startMonth,
    required DateTime endMonth,
    required String categoryId,
    String? subcategoryId,
    ExpenseType type = ExpenseType.expense,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(expenseRepositoryProvider).addSpreadExpenses(
            budgetId: budgetId,
            title: title,
            amount: amount,
            startMonth: startMonth,
            endMonth: endMonth,
            categoryId: categoryId,
            subcategoryId: subcategoryId,
            type: type,
          );
    });
    if (!state.hasError) {
      ref.invalidate(recentExpensesProvider(budgetId));
    }
  }
}

final manualExpenseControllerProvider =
    AsyncNotifierProvider<ManualExpenseController, void>(ManualExpenseController.new);
