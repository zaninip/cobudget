import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_provider.dart';

/// Schermata placeholder usata per verificare il setup di Riverpod e Supabase.
/// Verrà sostituita dalla dashboard descritta in UI_DESIGN.md.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = ref.watch(supabaseClientProvider);
    final hasSession = supabase.auth.currentSession != null;

    return Scaffold(
      appBar: AppBar(title: const Text('coBudget')),
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
              hasSession
                  ? 'Connesso a Supabase - sessione attiva'
                  : 'Connesso a Supabase - nessuna sessione',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
