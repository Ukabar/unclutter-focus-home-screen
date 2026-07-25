import 'package:flutter/material.dart';

import 'premium_components.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    required this.message,
    required this.icon,
    this.isError = false,
    super.key,
  });

  final String message;
  final IconData icon;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = isError
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }
}
