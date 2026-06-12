import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/error_message.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/supabase_budget_repository.dart';
import '../../domain/budget.dart';
import '../controllers/budgets_dashboard_controller.dart';

/// Schermata iniziale: crea/unisciti a un budget e accedi a quelli esistenti
/// (vedi UI_DESIGN.md - sezione 2 e ARCHITECTURE.md - flow 1).
class BudgetsDashboardScreen extends ConsumerStatefulWidget {
  const BudgetsDashboardScreen({super.key});

  @override
  ConsumerState<BudgetsDashboardScreen> createState() => _BudgetsDashboardScreenState();
}

class _BudgetsDashboardScreenState extends ConsumerState<BudgetsDashboardScreen> {
  final _createFormKey = GlobalKey<FormState>();
  final _joinFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _createBudget() {
    if (!_createFormKey.currentState!.validate()) return;
    ref
        .read(budgetsDashboardControllerProvider.notifier)
        .createBudget(_nameController.text.trim());
  }

  void _joinBudget() {
    if (!_joinFormKey.currentState!.validate()) return;
    ref
        .read(budgetsDashboardControllerProvider.notifier)
        .joinBudget(_inviteCodeController.text.trim());
  }

  Future<void> _leaveBudget(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uscire dal budget?'),
        content: Text(
          'Vuoi uscire da "${budget.name}"? Potrai tornare a farne parte con il codice invito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Esci'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(budgetRepositoryProvider).leaveBudget(budget.id);
      ref.invalidate(userBudgetsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Si è verificato un errore. Riprova.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(budgetsDashboardControllerProvider);
    final budgetsAsync = ref.watch(userBudgetsProvider);

    ref.listen<AsyncValue<Budget?>>(budgetsDashboardControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (budget) {
          if (budget != null) {
            _nameController.clear();
            _inviteCodeController.clear();
            context.go('/budget/${budget.id}');
          }
        },
        error: (error, _) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(errorMessage(error))));
        },
      );
    });

    final isLoading = dashboardState.isLoading;

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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _createFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Crea nuovo budget', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            'Crea un budget e ottieni un codice da condividere',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Nome budget'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Inserisci un nome';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: isLoading ? null : _createBudget,
                            child: const Text('Crea'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _joinFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Unisciti con codice', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            'Accedi a un budget esistente',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _inviteCodeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(labelText: 'Codice invito'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Inserisci un codice';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: isLoading ? null : _joinBudget,
                            child: const Text('Unisciti'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
                const SizedBox(height: 24),
                Text('I tuoi budget', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                budgetsAsync.when(
                  data: (budgets) {
                    if (budgets.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Non sei ancora membro di nessun budget. Crea o unisciti a uno per iniziare.',
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final budget in budgets)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.account_balance_wallet_outlined),
                              title: Text(budget.name),
                              subtitle: Text('Codice: ${budget.inviteCode}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Esci dal budget',
                                onPressed: () => _leaveBudget(budget),
                              ),
                              onTap: () => context.go('/budget/${budget.id}'),
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('Errore nel caricamento dei budget: $error'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
