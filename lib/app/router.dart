import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/supabase_provider.dart';
import '../core/utils/go_router_refresh_stream.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/budget/data/supabase_budget_repository.dart';
import '../features/budget/presentation/screens/budget_setup_screen.dart';
import '../features/expenses/presentation/screens/home_screen.dart';
import '../features/expenses/presentation/screens/manual_expense_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseClientProvider);

  final refreshListenable = GoRouterRefreshStream(supabase.auth.onAuthStateChange);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) async {
      final isLoggedIn = supabase.auth.currentSession != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      // Forza una rilettura del budget: subito dopo un login, lo stream
      // authStateChanges (da cui dipende currentBudgetProvider) potrebbe
      // non aver ancora propagato il nuovo stato, restituendo un valore
      // in cache non aggiornato (es. null da prima del login).
      final budget = await ref.refresh(currentBudgetProvider.future);
      final isBudgetSetup = state.matchedLocation == '/budget-setup';

      if (budget == null) {
        return isBudgetSetup ? null : '/budget-setup';
      }

      if (isLoggingIn || isBudgetSetup) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/budget-setup',
        name: 'budget-setup',
        builder: (context, state) => const BudgetSetupScreen(),
      ),
      GoRoute(
        path: '/expenses/new',
        name: 'expense-new',
        builder: (context, state) => const ManualExpenseScreen(),
      ),
    ],
  );
});
