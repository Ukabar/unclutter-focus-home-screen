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
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final bool largeText = textScale >= 1.3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          children: <Widget>[
            ReorderableDragStartListener(
              index: index,
              child: Semantics(
                label: 'Drag ${entry.name}',
                child: Container(
                  width: 44,
                  height: 44,
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
            ),
            SizedBox(width: largeText ? 8 : 10),
            AppGlyph(name: entry.name, size: largeText ? 40 : 44),
            SizedBox(width: largeText ? 10 : 12),
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
            const SizedBox(width: 8),
            _TileActionsMenu(
              entry: entry,
              isFirst: isFirst,
              isLast: isLast,
              onMoveUp: onMoveUp,
              onMoveDown: onMoveDown,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

enum _TileAction { moveUp, moveDown, edit, delete }

class _TileActionsMenu extends StatelessWidget {
  const _TileActionsMenu({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
  });

  final LauncherEntry entry;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox.square(
      dimension: 44,
      child: PopupMenuButton<_TileAction>(
        key: Key('actions-${entry.id}'),
        tooltip: 'Actions for ${entry.name}',
        icon: const Icon(CupertinoIcons.ellipsis_circle),
        color: theme.colorScheme.surfaceContainerHighest,
        onSelected: (_TileAction action) {
          switch (action) {
            case _TileAction.moveUp:
              onMoveUp();
            case _TileAction.moveDown:
              onMoveDown();
            case _TileAction.edit:
              onEdit();
            case _TileAction.delete:
              onDelete();
          }
        },
        itemBuilder: (BuildContext context) {
          return <PopupMenuEntry<_TileAction>>[
            PopupMenuItem<_TileAction>(
              key: Key('move-up-${entry.id}'),
              value: _TileAction.moveUp,
              enabled: !isFirst,
              child: const _TileMenuItem(
                icon: CupertinoIcons.chevron_up,
                label: 'Move up',
              ),
            ),
            PopupMenuItem<_TileAction>(
              key: Key('move-down-${entry.id}'),
              value: _TileAction.moveDown,
              enabled: !isLast,
              child: const _TileMenuItem(
                icon: CupertinoIcons.chevron_down,
                label: 'Move down',
              ),
            ),
            PopupMenuItem<_TileAction>(
              key: Key('edit-${entry.id}'),
              value: _TileAction.edit,
              child: const _TileMenuItem(
                icon: CupertinoIcons.pencil,
                label: 'Edit',
              ),
            ),
            PopupMenuItem<_TileAction>(
              key: Key('delete-${entry.id}'),
              value: _TileAction.delete,
              child: _TileMenuItem(
                icon: CupertinoIcons.trash,
                label: 'Delete',
                color: theme.colorScheme.error,
              ),
            ),
          ];
        },
      ),
    );
  }
}

class _TileMenuItem extends StatelessWidget {
  const _TileMenuItem({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color effectiveColor = color ?? theme.colorScheme.onSurface;
    return Row(
      children: <Widget>[
        Icon(icon, size: 19, color: effectiveColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: effectiveColor),
          ),
        ),
      ],
    );
  }
}
