import 'package:flutter/material.dart';

import 'premium_components.dart';

class EssentialAppsEmptyState extends StatelessWidget {
  const EssentialAppsEmptyState({required this.onAddPressed, super.key});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
      children: <Widget>[
        PremiumCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Choose what deserves a place here.',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
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
              PremiumActionButton(
                keyName: 'empty-add-app-button',
                label: 'Add first app',
                icon: Icons.add,
                onPressed: onAddPressed,
                isPrimary: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
