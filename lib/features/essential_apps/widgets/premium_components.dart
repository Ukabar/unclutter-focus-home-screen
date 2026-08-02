import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../catalog/catalog_app.dart';
import '../models/launcher_entry.dart';

class PremiumScaffoldBand extends StatelessWidget {
  const PremiumScaffoldBand({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF07110F), AppTheme.ink],
        ),
      ),
      child: child,
    );
  }
}

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: padding,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.82,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(onTap: onTap, child: content);
  }
}

class PremiumSectionHeader extends StatelessWidget {
  const PremiumSectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.35;
        final Widget text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ],
        );

        final Widget? trailing = action;
        if (stacked && trailing != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              text,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: trailing),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: text),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 12),
              Flexible(
                child: Align(alignment: Alignment.centerRight, child: trailing),
              ),
            ],
          ],
        );
      },
    );
  }
}

class PremiumActionButton extends StatefulWidget {
  const PremiumActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.keyName,
    this.isPrimary = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? keyName;
  final bool isPrimary;

  @override
  State<PremiumActionButton> createState() => _PremiumActionButtonState();
}

class _PremiumActionButtonState extends State<PremiumActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color background = widget.isPrimary
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final Color foreground = widget.isPrimary
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.97 : 1,
        child: FilledButton.icon(
          key: widget.keyName == null ? null : Key(widget.keyName!),
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, size: 19),
          label: Text(widget.label),
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: background.withValues(alpha: 0.46),
            disabledForegroundColor: foreground.withValues(alpha: 0.46),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}

class AppGlyph extends StatelessWidget {
  const AppGlyph({required this.name, this.size = 44, super.key});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final int seed = name.codeUnits.fold<int>(0, (int a, int b) => a + b);
    final Color accent = Theme.of(context).colorScheme.primary;
    final List<Color> colors = <Color>[
      accent,
      AppTheme.sage,
      const Color(0xFFD99B7E),
      const Color(0xFFB9A7FF),
      const Color(0xFFFFC773),
    ];
    final Color color = colors[seed % colors.length];
    final String trimmedName = name.trim();
    final String initial = trimmedName.isEmpty
        ? '?'
        : String.fromCharCode(trimmedName.runes.first).toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

class SelectedCounter extends StatelessWidget {
  const SelectedCounter({required this.count, this.limit = 12, super.key});

  final int count;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count / $limit selected',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class CatalogCategoryGroup {
  const CatalogCategoryGroup({required this.title, required this.apps});

  final String title;
  final List<CatalogApp> apps;
}

class WidgetFramePreview extends StatelessWidget {
  const WidgetFramePreview({
    required this.entries,
    required this.family,
    super.key,
  });

  final List<LauncherEntry> entries;
  final String family;

  int get _limit {
    return switch (family) {
      'Small' => 3,
      'Medium' => 6,
      _ => 12,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<LauncherEntry> visible = entries.take(_limit).toList();
    final double height = switch (family) {
      'Small' => 150,
      'Medium' => 170,
      _ => 300,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      height: height,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1117),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                CupertinoIcons.square_grid_2x2_fill,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Essential Apps',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            Text(
              'Open Stillscreen to choose apps.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) {
                  return Row(
                    children: <Widget>[
                      AppGlyph(name: visible[index].name, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          visible[index].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        CupertinoIcons.arrow_up_right,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 16,
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
