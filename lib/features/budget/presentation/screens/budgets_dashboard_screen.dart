import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_bar_icon_button.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/supabase_budget_repository.dart';
import '../../domain/budget.dart';
import '../widgets/budget_form_dialogs.dart';

/// Schermata iniziale: crea/unisciti a un budget e accedi a quelli esistenti
/// (vedi UI_DESIGN.md - sezione 2 e ARCHITECTURE.md - flow 1).
class BudgetsDashboardScreen extends ConsumerStatefulWidget {
  const BudgetsDashboardScreen({super.key});

  @override
  ConsumerState<BudgetsDashboardScreen> createState() => _BudgetsDashboardScreenState();
}

class _BudgetsDashboardScreenState extends ConsumerState<BudgetsDashboardScreen> {
  Future<void> _openCreate() async {
    final budget = await showDialog<Budget>(
      context: context,
      builder: (_) => const CreateBudgetDialog(),
    );
    if (budget != null && mounted) context.go('/budget/${budget.id}');
  }

  Future<void> _openJoin() async {
    final budget = await showDialog<Budget>(
      context: context,
      builder: (_) => const JoinBudgetDialog(),
    );
    if (budget != null && mounted) context.go('/budget/${budget.id}');
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
    final budgetsAsync = ref.watch(userBudgetsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('coBudget'),
        actions: [
          AppBarIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Impostazioni',
            onPressed: () => context.push('/settings'),
          ),
          AppBarIconButton(
            icon: Icons.logout,
            tooltip: 'Logout',
            color: theme.colorScheme.error,
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _ActionCard(
                  title: 'Crea nuovo budget',
                  subtitle: 'Crea un budget e ottieni un codice condivisibile',
                  icon: Icons.add,
                  primary: true,
                  onTap: _openCreate,
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  title: 'Unisciti con codice',
                  subtitle: 'Accedi a un budget esistente',
                  icon: Icons.vpn_key_outlined,
                  primary: false,
                  onTap: _openJoin,
                ),
                const SizedBox(height: 28),
                Text('I tuoi budget', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                budgetsAsync.when(
                  data: (budgets) {
                    if (budgets.isEmpty) {
                      return Text(
                        'Non sei ancora membro di nessun budget. Crea o unisciti a uno per iniziare.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final budget in budgets) ...[
                          _BudgetTile(
                            budget: budget,
                            onTap: () => context.go('/budget/${budget.id}'),
                            onLeave: () => _leaveBudget(budget),
                          ),
                          const SizedBox(height: 12),
                        ],
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

/// Card "call to action" con titolo, sottotitolo e pulsante icona a destra.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.primary,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _IconBadge(icon: icon, primary: primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Riquadro icona: pieno con glow per l'azione primaria, tonale per le altre.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.primary});

  final IconData icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: primary
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.primaryContainer],
              )
            : null,
        color: primary ? null : scheme.surfaceContainerHighest,
        border: primary ? null : Border.all(color: scheme.outline),
        boxShadow: primary
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.45),
                  blurRadius: 22,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: 28,
        color: primary ? scheme.onPrimary : scheme.primary,
      ),
    );
  }
}

/// Voce della lista "I tuoi budget".
class _BudgetTile extends StatelessWidget {
  const _BudgetTile({required this.budget, required this.onTap, required this.onLeave});

  final Budget budget;
  final VoidCallback onTap;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(budget.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Codice: ${budget.inviteCode}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Esci dal budget',
                onPressed: onLeave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
