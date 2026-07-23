import 'package:flutter/material.dart';

import '../models/launcher_entry.dart';

class LauncherEntryTile extends StatelessWidget {
  const LauncherEntryTile({
    required this.entry,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    super.key,
  });

  final LauncherEntry entry;
  final int index;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.surface,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          title: Text(entry.name),
          subtitle: Text(
            entry.category == null
                ? entry.launchUrl
                : '${entry.category} • ${entry.launchUrl}',
          ),
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          trailing: Wrap(
            spacing: 2,
            children: <Widget>[
              IconButton(
                key: Key('move-up-${entry.id}'),
                tooltip: 'Move ${entry.name} up',
                onPressed: isFirst ? null : onMoveUp,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                key: Key('move-down-${entry.id}'),
                tooltip: 'Move ${entry.name} down',
                onPressed: isLast ? null : onMoveDown,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              IconButton(
                key: Key('edit-${entry.id}'),
                tooltip: 'Edit ${entry.name}',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: Key('delete-${entry.id}'),
                tooltip: 'Remove ${entry.name}',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
