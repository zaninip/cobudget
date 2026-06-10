import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../domain/budget.dart';
import '../domain/budget_repository.dart';

class SupabaseBudgetRepository implements BudgetRepository {
  SupabaseBudgetRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Budget?> getCurrentBudget() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final membership = await _client
        .from('budget_members')
        .select('budgets(*)')
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();

    if (membership == null) return null;
    return Budget.fromMap(membership['budgets'] as Map<String, dynamic>);
  }

  @override
  Future<Budget> createBudget(String name) async {
    final result = await _client.rpc('create_budget', params: {'p_name': name});
    return Budget.fromMap(result as Map<String, dynamic>);
  }

  @override
  Future<Budget> joinBudget(String inviteCode) async {
    final result = await _client.rpc('join_budget', params: {'p_invite_code': inviteCode});
    return Budget.fromMap(result as Map<String, dynamic>);
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return SupabaseBudgetRepository(ref.watch(supabaseClientProvider));
});

/// Il budget dell'utente corrente, o `null` se non ne ha ancora uno.
/// Si ricalcola automaticamente ad ogni cambio di stato dell'autenticazione.
final currentBudgetProvider = FutureProvider<Budget?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(budgetRepositoryProvider).getCurrentBudget();
});
