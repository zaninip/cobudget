import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/supabase_provider.dart';
import '../core/utils/go_router_refresh_stream.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/budget/presentation/screens/budgets_dashboard_screen.dart';
import '../features/expenses/presentation/screens/home_screen.dart';
import '../features/expenses/presentation/screens/manual_expense_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseClientProvider);

  final refreshListenable = GoRouterRefreshStream(supabase.auth.onAuthStateChange);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final isLoggedIn = supabase.auth.currentSession != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }
      if (isLoggingIn) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const BudgetsDashboardScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/budget/:budgetId',
        name: 'budget-home',
        builder: (context, state) => HomeScreen(budgetId: state.pathParameters['budgetId']!),
      ),
      GoRoute(
        path: '/budget/:budgetId/expenses/new',
        name: 'expense-new',
        builder: (context, state) =>
            ManualExpenseScreen(budgetId: state.pathParameters['budgetId']!),
      ),
    ],
  );
});
