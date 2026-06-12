import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../domain/budget.dart';
import '../domain/budget_repository.dart';

class SupabaseBudgetRepository implements BudgetRepository {
  SupabaseBudgetRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Budget>> getUserBudgets() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final result = await _client
        .from('budget_members')
        .select('budgets(*)')
        .eq('user_id', userId)
        .order('joined_at');

    return (result as List)
        .map((e) => Budget.fromMap(e['budgets'] as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Budget> getBudgetById(String budgetId) async {
    final result = await _client.from('budgets').select().eq('id', budgetId).single();
    return Budget.fromMap(result);
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

  @override
  Future<void> leaveBudget(String budgetId) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('budget_members').delete().eq('budget_id', budgetId).eq('user_id', userId);
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return SupabaseBudgetRepository(ref.watch(supabaseClientProvider));
});

/// Tutti i budget di cui l'utente corrente è membro.
/// Si ricalcola automaticamente ad ogni cambio di stato dell'autenticazione.
final userBudgetsProvider = FutureProvider<List<Budget>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(budgetRepositoryProvider).getUserBudgets();
});

/// Il budget con l'id indicato.
final budgetByIdProvider = FutureProvider.family<Budget, String>((ref, budgetId) {
  return ref.watch(budgetRepositoryProvider).getBudgetById(budgetId);
});
