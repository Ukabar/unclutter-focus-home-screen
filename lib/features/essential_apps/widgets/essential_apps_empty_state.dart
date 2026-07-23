import 'package:flutter/material.dart';

class EssentialAppsEmptyState extends StatelessWidget {
  const EssentialAppsEmptyState({required this.onAddPressed, super.key});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
      children: <Widget>[
        Text(
          'Choose what deserves a place here.',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Add a few essential apps. URL formats are checked, but iOS may still refuse a link if the target app does not support it.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('empty-add-app-button'),
          onPressed: onAddPressed,
          icon: const Icon(Icons.add),
          label: const Text('Add first app'),
        ),
      ],
    );
  }
}
