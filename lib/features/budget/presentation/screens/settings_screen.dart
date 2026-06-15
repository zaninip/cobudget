import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme_mode_controller.dart';
import '../../data/supabase_budget_repository.dart';
import '../../domain/budget_member.dart';

/// Impostazioni dell'app. Se [budgetId] è valorizzato mostra anche il codice
/// invito e la lista membri del budget (vedi UI_DESIGN.md - sezione 9);
/// altrimenti mostra solo le impostazioni generali (tema).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.budgetId});

  final String? budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final budgetId = this.budgetId;

    final budget = budgetId != null ? ref.watch(budgetByIdProvider(budgetId)) : null;
    final membersAsync = budgetId != null ? ref.watch(budgetMembersProvider(budgetId)) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          budget?.maybeWhen(data: (value) => value.name, orElse: () => 'Impostazioni') ??
              'Impostazioni',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (budget != null) ...[
                  const _SectionTitle('Codice invito'),
                  const SizedBox(height: 8),
                  budget.when(
                    data: (value) => _InviteCodeCard(code: value.inviteCode),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Text('Errore nel caricamento del budget: $error'),
                  ),
                  const SizedBox(height: 24),
                ],
                if (membersAsync != null) ...[
                  membersAsync.when(
                    data: (members) => _MembersSection(members: members),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Text('Errore nel caricamento dei membri: $error'),
                  ),
                  const SizedBox(height: 24),
                ],
                const _SectionTitle('Tema'),
                const SizedBox(height: 8),
                _ThemeSelector(
                  themeMode: themeMode,
                  onChanged: (mode) =>
                      ref.read(themeModeControllerProvider.notifier).setThemeMode(mode),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code});

  final String code;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Codice invito copiato')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          code,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: const Text('Condividilo per far entrare altre persone'),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copia codice',
          onPressed: () => _copy(context),
        ),
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  const _MembersSection({required this.members});

  final List<BudgetMember> members;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle('Membri (${members.length})'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final member in members)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(member.isSelf ? '${member.name} (tu)' : member.name),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.themeMode, required this.onChanged});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    // Solo Chiaro/Scuro. Se il tema segue ancora il sistema, evidenziamo
    // l'opzione attualmente in uso in base alla luminosità della piattaforma.
    final effective = switch (themeMode) {
      ThemeMode.light => ThemeMode.light,
      ThemeMode.dark => ThemeMode.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context) == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
    };

    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Chiaro'),
          icon: Icon(Icons.light_mode),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Scuro'),
          icon: Icon(Icons.dark_mode),
        ),
      ],
      selected: {effective},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
