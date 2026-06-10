import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../budget/data/supabase_budget_repository.dart';

/// Schermata placeholder usata per verificare il setup di Riverpod e Supabase.
/// Verrà sostituita dalla dashboard descritta in UI_DESIGN.md.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateChangesProvider);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final budget = ref.watch(currentBudgetProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('coBudget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Esci',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('coBudget', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              user != null
                  ? 'Connesso come ${user.email}'
                  : 'Connesso a Supabase - nessuna sessione',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              budget.when(
                data: (value) => value != null
                    ? 'Budget: ${value.name} (codice: ${value.inviteCode})'
                    : 'Nessun budget',
                loading: () => 'Caricamento budget...',
                error: (_, _) => 'Errore nel caricamento del budget',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
