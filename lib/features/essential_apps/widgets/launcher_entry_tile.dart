import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/launcher_entry.dart';
import 'premium_components.dart';

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
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: <Widget>[
            ReorderableDragStartListener(
              index: index,
              child: Container(
                width: 34,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.42,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  CupertinoIcons.line_horizontal_3,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 17,
                ),
              ),
            ),
            const SizedBox(width: 12),
            AppGlyph(name: entry.name, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.category == null
                        ? entry.launchUrl
                        : '${entry.category} - ${entry.launchUrl}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _TileIconButton(
              key: Key('move-up-${entry.id}'),
              tooltip: 'Move ${entry.name} up',
              icon: CupertinoIcons.chevron_up,
              onPressed: isFirst ? null : onMoveUp,
            ),
            _TileIconButton(
              key: Key('move-down-${entry.id}'),
              tooltip: 'Move ${entry.name} down',
              icon: CupertinoIcons.chevron_down,
              onPressed: isLast ? null : onMoveDown,
            ),
            _TileIconButton(
              key: Key('edit-${entry.id}'),
              tooltip: 'Edit ${entry.name}',
              icon: CupertinoIcons.pencil,
              onPressed: onEdit,
            ),
            _TileIconButton(
              key: Key('delete-${entry.id}'),
              tooltip: 'Remove ${entry.name}',
              icon: CupertinoIcons.trash,
              onPressed: onDelete,
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TileIconButton extends StatelessWidget {
  const _TileIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isDestructive = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 19,
      color: isDestructive
          ? theme.colorScheme.error
          : theme.colorScheme.onSurfaceVariant,
      disabledColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.24),
      icon: Icon(icon),
    );
  }
}
