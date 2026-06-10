import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/budget.dart';
import '../controllers/budget_setup_controller.dart';

/// Schermata di configurazione budget al primo accesso (vedi UI_DESIGN.md - sezione 2).
class BudgetSetupScreen extends ConsumerStatefulWidget {
  const BudgetSetupScreen({super.key});

  @override
  ConsumerState<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends ConsumerState<BudgetSetupScreen> {
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

  String _errorMessage(Object error) {
    if (error is PostgrestException) return error.message;
    return 'Si è verificato un errore. Riprova.';
  }

  void _createBudget() {
    if (!_createFormKey.currentState!.validate()) return;
    ref
        .read(budgetSetupControllerProvider.notifier)
        .createBudget(_nameController.text.trim());
  }

  void _joinBudget() {
    if (!_joinFormKey.currentState!.validate()) return;
    ref
        .read(budgetSetupControllerProvider.notifier)
        .joinBudget(_inviteCodeController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(budgetSetupControllerProvider);

    ref.listen<AsyncValue<Budget?>>(budgetSetupControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (budget) {
          if (budget != null) context.go('/');
        },
        error: (error, _) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
        },
      );
    });

    final isLoading = setupState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Configura il tuo budget',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _createFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Crea nuovo', style: Theme.of(context).textTheme.titleMedium),
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
                  Text('oppure', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _joinFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Unisciti', style: Theme.of(context).textTheme.titleMedium),
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
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
