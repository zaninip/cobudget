import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase_budget_repository.dart';
import '../../domain/budget.dart';

/// Stato della creazione/accesso al budget (vedi ARCHITECTURE.md - flow 1).
class BudgetSetupController extends AsyncNotifier<Budget?> {
  @override
  FutureOr<Budget?> build() => null;

  Future<void> createBudget(String name) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(budgetRepositoryProvider).createBudget(name),
    );
    if (!state.hasError) {
      ref.invalidate(currentBudgetProvider);
    }
  }

  Future<void> joinBudget(String inviteCode) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(budgetRepositoryProvider).joinBudget(inviteCode),
    );
    if (!state.hasError) {
      ref.invalidate(currentBudgetProvider);
    }
  }
}

final budgetSetupControllerProvider =
    AsyncNotifierProvider<BudgetSetupController, Budget?>(BudgetSetupController.new);
