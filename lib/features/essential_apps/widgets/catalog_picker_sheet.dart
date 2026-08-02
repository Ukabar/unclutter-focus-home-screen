import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/brand/stillscreen_logo.dart';
import '../../../core/theme/app_theme.dart';
import '../catalog/catalog_app.dart';
import '../models/launcher_entry.dart';
import '../validation/launch_url_validator.dart';
import 'premium_components.dart';

class CatalogPickerSheet extends StatefulWidget {
  const CatalogPickerSheet({
    required this.apps,
    required this.selectedEntries,
    required this.onManualEntry,
    this.onSelectionComplete,
    this.isFullScreen = false,
    super.key,
  });

  final List<CatalogApp> apps;
  final List<LauncherEntry> selectedEntries;
  final Future<LauncherEntry?> Function() onManualEntry;
  final ValueChanged<List<LauncherEntry>>? onSelectionComplete;
  final bool isFullScreen;

  @override
  State<CatalogPickerSheet> createState() => _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends State<CatalogPickerSheet> {
  static const int _selectionLimit = 12;
  static const Color _background = Color(0xFF000000);
  static const Color _card = Color(0xFF1C1C1E);
  static const Color _line = Color(0xFF2C2C2E);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late List<LauncherEntry> _selectedEntries;
  String _query = '';
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _selectedEntries = List<LauncherEntry>.of(widget.selectedEntries);
    _searchFocusNode.addListener(_handleSearchFocusChanged);
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleSearchFocusChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSearchFocusChanged() {
    setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
  }

  Set<String> get _selectedKeys {
    return _selectedEntries.map((LauncherEntry entry) {
      return LaunchUrlValidator.duplicateKey(entry.launchUrl);
    }).toSet();
  }

  int get _selectedCount => _selectedEntries.length;

  bool get _isLimitReached => _selectedCount >= _selectionLimit;

  String get _continueLabel {
    if (_selectedCount == 0) {
      return 'Continue';
    }
    if (_isLimitReached) {
      return 'Limit reached';
    }
    return 'Continue with $_selectedCount ${_selectedCount == 1 ? 'app' : 'apps'}';
  }

  void _toggleApp(CatalogApp app) {
    final String key = LaunchUrlValidator.duplicateKey(app.launchUrl);
    final int selectedIndex = _selectedEntries.indexWhere((
      LauncherEntry entry,
    ) {
      return LaunchUrlValidator.duplicateKey(entry.launchUrl) == key;
    });

    if (selectedIndex != -1) {
      setState(() => _selectedEntries.removeAt(selectedIndex));
      return;
    }

    if (_isLimitReached) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can keep up to 12 apps.')),
      );
      return;
    }

    setState(() => _selectedEntries.add(app.toLauncherEntry()));
  }

  void _removeSelectedEntry(LauncherEntry entry) {
    setState(() {
      _selectedEntries.removeWhere(
        (LauncherEntry selected) => selected.id == entry.id,
      );
    });
  }

  Future<void> _openManualEntry() async {
    if (_isLimitReached) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can keep up to 12 apps.')),
      );
      return;
    }

    final LauncherEntry? entry = await widget.onManualEntry();
    if (entry == null || !mounted) {
      return;
    }

    final String key = LaunchUrlValidator.duplicateKey(entry.launchUrl);
    final bool alreadySelected = _selectedEntries.any((LauncherEntry selected) {
      return LaunchUrlValidator.duplicateKey(selected.launchUrl) == key;
    });

    if (alreadySelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That app is already in your list.')),
      );
      return;
    }

    setState(() => _selectedEntries.add(entry));
  }

  void _finishSelection() {
    if (_selectedEntries.isEmpty) {
      return;
    }
    final List<LauncherEntry> result = List<LauncherEntry>.unmodifiable(
      _selectedEntries,
    );
    final ValueChanged<List<LauncherEntry>>? onSelectionComplete =
        widget.onSelectionComplete;
    if (onSelectionComplete != null) {
      onSelectionComplete(result);
      return;
    }
    Navigator.of(context).pop(result);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double height = widget.isFullScreen
        ? mediaQuery.size.height
        : mediaQuery.size.height * 0.92;
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final List<CatalogApp> filteredApps = _filteredApps();
    final List<_CatalogSection> sections = _catalogSections(filteredApps);

    return DecoratedBox(
      decoration: const BoxDecoration(color: _background),
      child: SafeArea(
        top: widget.isFullScreen,
        child: SizedBox(
          height: height,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: mediaQuery.size.width >= 600
                    ? 760
                    : mediaQuery.size.width,
              ),
              child: Stack(
                children: <Widget>[
                  CustomScrollView(
                    key: const PageStorageKey<String>('catalog-picker-scroll'),
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: <Widget>[
                      SliverToBoxAdapter(
                        child: _AppPickerHeader(
                          count: _selectedCount,
                          limit: _selectionLimit,
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          isFocused: _isSearchFocused,
                          onChanged: (String value) {
                            setState(() => _query = _normalizedQuery(value));
                          },
                          onClear: _query.isEmpty ? null : _clearSearch,
                          onManualEntry: _openManualEntry,
                        ),
                      ),
                      if (_selectedEntries.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _SelectedAppsSection(
                            entries: _selectedEntries,
                            onRemove: _removeSelectedEntry,
                          ),
                        ),
                      if (filteredApps.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptySearchState(
                            onManualEntry: _openManualEntry,
                          ),
                        )
                      else
                        SliverList.builder(
                          itemCount: sections.length,
                          itemBuilder: (BuildContext context, int index) {
                            return _AppSectionCard(
                              section: sections[index],
                              selectedKeys: _selectedKeys,
                              isLimitReached: _isLimitReached,
                              onToggle: _toggleApp,
                            );
                          },
                        ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: 118 + bottomInset),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _BottomSelectionAction(
                      label: _continueLabel,
                      count: _selectedCount,
                      limit: _selectionLimit,
                      onPressed: _selectedCount == 0 ? null : _finishSelection,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<CatalogApp> _filteredApps() {
    final String query = _query;
    final List<CatalogApp> matches = widget.apps.where((CatalogApp app) {
      if (query.isEmpty) {
        return true;
      }
      final String name = _normalizedQuery(app.name);
      final String category = _normalizedQuery(app.category ?? '');
      final String launchUrl = _normalizedQuery(app.launchUrl);
      return name.startsWith(query) ||
          name.contains(query) ||
          category.contains(query) ||
          launchUrl.contains(query);
    }).toList();

    matches.sort((CatalogApp a, CatalogApp b) {
      final String aName = _normalizedQuery(a.name);
      final String bName = _normalizedQuery(b.name);
      final bool aStarts = query.isNotEmpty && aName.startsWith(query);
      final bool bStarts = query.isNotEmpty && bName.startsWith(query);
      if (aStarts != bStarts) {
        return aStarts ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return matches;
  }

  List<_CatalogSection> _catalogSections(List<CatalogApp> apps) {
    final Map<String, List<CatalogApp>> grouped = <String, List<CatalogApp>>{
      'Essential System Apps': <CatalogApp>[],
      'System Apps': <CatalogApp>[],
      'Other Apps': <CatalogApp>[],
      'Custom Apps': <CatalogApp>[],
    };

    for (final CatalogApp app in apps) {
      grouped[_sectionTitleFor(app)]!.add(app);
    }

    return grouped.entries
        .where((MapEntry<String, List<CatalogApp>> entry) {
          return entry.value.isNotEmpty;
        })
        .map((MapEntry<String, List<CatalogApp>> entry) {
          return _CatalogSection(title: entry.key, apps: entry.value);
        })
        .toList();
  }

  String _sectionTitleFor(CatalogApp app) {
    final String category = (app.category ?? '').toLowerCase();
    final String name = app.name.toLowerCase();
    if (category.isEmpty) {
      return 'Custom Apps';
    }
    if (name == 'phone' ||
        name == 'messages' ||
        name == 'mail' ||
        name == 'facetime' ||
        name == 'maps' ||
        name == 'calendar') {
      return 'Essential System Apps';
    }
    if (category == 'tools' || category == 'media') {
      return 'System Apps';
    }
    return 'Other Apps';
  }

  String _normalizedQuery(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }
}

class _AppPickerHeader extends StatelessWidget {
  const _AppPickerHeader({
    required this.count,
    required this.limit,
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.onChanged,
    required this.onClear,
    required this.onManualEntry,
  });

  final int count;
  final int limit;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double topPadding = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 18 + topPadding, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: _CatalogPickerSheetState._line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 26),
          const StillscreenLogo(size: 36),
          const SizedBox(height: 18),
          Text(
            'Pick Essential Apps',
            style: theme.textTheme.displaySmall?.copyWith(
              color: AppTheme.ivory,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              height: 1.05,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose a few apps for your quiet Home Screen. You can change them anytime.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.ivory.withValues(alpha: 0.78),
              fontSize: 17,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              _SelectedCountBadge(count: count, limit: limit),
              const SizedBox(width: 10),
              _HeaderCustomButton(onPressed: onManualEntry),
            ],
          ),
          const SizedBox(height: 16),
          _AppSearchField(
            controller: controller,
            focusNode: focusNode,
            isFocused: isFocused,
            onChanged: onChanged,
            onClear: onClear,
          ),
        ],
      ),
    );
  }
}

class _SelectedCountBadge extends StatelessWidget {
  const _SelectedCountBadge({required this.count, required this.limit});

  final int count;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Text(
        '$count / $limit selected',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeaderCustomButton extends StatelessWidget {
  const _HeaderCustomButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: 'Add custom app',
      child: CupertinoButton(
        key: const Key('manual-entry-button'),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: _CatalogPickerSheetState._card,
        borderRadius: BorderRadius.circular(999),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(CupertinoIcons.pencil, size: 17, color: accent),
            const SizedBox(width: 7),
            Text(
              'Custom',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.ivory,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppSearchField extends StatelessWidget {
  const _AppSearchField({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: 56,
      decoration: BoxDecoration(
        color: _CatalogPickerSheetState._card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isFocused
              ? accent.withValues(alpha: 0.52)
              : _CatalogPickerSheetState._line,
        ),
      ),
      child: CupertinoTextField(
        key: const Key('catalog-search-field'),
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        keyboardAppearance: Brightness.dark,
        textInputAction: TextInputAction.search,
        cursorColor: accent,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppTheme.ivory,
          fontWeight: FontWeight.w600,
        ),
        placeholder: 'Search an app name',
        placeholderStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppTheme.ivory.withValues(alpha: 0.42),
        ),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 18, right: 9),
          child: Icon(
            CupertinoIcons.search,
            size: 20,
            color: AppTheme.ivory.withValues(alpha: 0.55),
          ),
        ),
        suffix: onClear == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CupertinoButton(
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                  onPressed: onClear,
                  child: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 20,
                    color: AppTheme.ivory.withValues(alpha: 0.46),
                  ),
                ),
              ),
        decoration: const BoxDecoration(color: Colors.transparent),
        padding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }
}

class _SelectedAppsSection extends StatelessWidget {
  const _SelectedAppsSection({required this.entries, required this.onRemove});

  final List<LauncherEntry> entries;
  final ValueChanged<LauncherEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Selected Apps',
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 66,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (BuildContext context, int index) {
            final LauncherEntry entry = entries[index];
            return _SelectedEntryChip(
              entry: entry,
              onRemove: () => onRemove(entry),
            );
          },
        ),
      ),
    );
  }
}

class _AppSectionCard extends StatelessWidget {
  const _AppSectionCard({
    required this.section,
    required this.selectedKeys,
    required this.isLimitReached,
    required this.onToggle,
  });

  final _CatalogSection section;
  final Set<String> selectedKeys;
  final bool isLimitReached;
  final ValueChanged<CatalogApp> onToggle;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: section.title,
      child: Column(
        children: List<Widget>.generate(section.apps.length, (int index) {
          final CatalogApp app = section.apps[index];
          final bool isSelected = selectedKeys.contains(
            LaunchUrlValidator.duplicateKey(app.launchUrl),
          );
          return _AppSelectionRow(
            app: app,
            isSelected: isSelected,
            isDisabled: isLimitReached && !isSelected,
            showDivider: index < section.apps.length - 1,
            onTap: () => onToggle(app),
          );
        }),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 9),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.ivory.withValues(alpha: 0.56),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _CatalogPickerSheetState._card,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _CatalogPickerSheetState._line),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

class _AppSelectionRow extends StatefulWidget {
  const _AppSelectionRow({
    required this.app,
    required this.isSelected,
    required this.isDisabled,
    required this.showDivider,
    required this.onTap,
  });

  final CatalogApp app;
  final bool isSelected;
  final bool isDisabled;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  State<_AppSelectionRow> createState() => _AppSelectionRowState();
}

class _AppSelectionRowState extends State<_AppSelectionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = theme.colorScheme.primary;
    final Color textColor = widget.isDisabled
        ? AppTheme.ivory.withValues(alpha: 0.38)
        : AppTheme.ivory;

    return Semantics(
      button: true,
      label: widget.isSelected
          ? 'Remove ${widget.app.name}'
          : 'Add ${widget.app.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          scale: _pressed ? 0.992 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 80),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? accent.withValues(alpha: 0.07)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                  child: Row(
                    children: <Widget>[
                      AppGlyph(name: widget.app.name, size: 46),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.app.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: textColor,
                                fontWeight: widget.isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.app.category ?? widget.app.launchUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.ivory.withValues(alpha: 0.48),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _SelectionGlyph(
                        isSelected: widget.isSelected,
                        isDisabled: widget.isDisabled,
                      ),
                    ],
                  ),
                ),
                if (widget.showDivider)
                  Padding(
                    padding: const EdgeInsets.only(left: 76),
                    child: Divider(
                      height: 1,
                      thickness: 0.6,
                      color: _CatalogPickerSheetState._line,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedEntryChip extends StatelessWidget {
  const _SelectedEntryChip({required this.entry, required this.onRemove});

  final LauncherEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: 'Remove ${entry.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRemove,
        child: Container(
          constraints: const BoxConstraints(minWidth: 120, maxWidth: 178),
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppGlyph(name: entry.name, size: 34),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.ivory,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                CupertinoIcons.check_mark_circled_solid,
                size: 18,
                color: AppTheme.sage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionGlyph extends StatelessWidget {
  const _SelectionGlyph({required this.isSelected, required this.isDisabled});

  final bool isSelected;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    final Color color = isSelected
        ? AppTheme.sage
        : isDisabled
        ? AppTheme.ivory.withValues(alpha: 0.26)
        : accent;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: Icon(
        isSelected
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.add_circled_solid,
        key: ValueKey<bool>(isSelected),
        size: 24,
        color: color,
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.onManualEntry});

  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 150),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _CatalogPickerSheetState._card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _CatalogPickerSheetState._line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  CupertinoIcons.search,
                  color: AppTheme.ivory.withValues(alpha: 0.54),
                  size: 30,
                ),
                const SizedBox(height: 14),
                Text(
                  'No apps found',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.ivory,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try a different name or add a custom app.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ivory.withValues(alpha: 0.62),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                CupertinoButton(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  color: accent,
                  borderRadius: BorderRadius.circular(18),
                  onPressed: onManualEntry,
                  child: Text(
                    'Add Custom App',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomSelectionAction extends StatelessWidget {
  const _BottomSelectionAction({
    required this.label,
    required this.count,
    required this.limit,
    required this.onPressed,
  });

  final String label;
  final int count;
  final int limit;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.paddingOf(context).bottom;
    final bool isDisabled = onPressed == null;
    final Color accent = Theme.of(context).colorScheme.primary;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: 0),
                Colors.black.withValues(alpha: 0.86),
                Colors.black,
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 14 + bottomPadding),
            child: SizedBox(
              width: double.infinity,
              height: 62,
              child: FilledButton(
                key: const Key('selection-continue-button'),
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: isDisabled
                      ? _CatalogPickerSheetState._card
                      : accent,
                  foregroundColor: isDisabled
                      ? AppTheme.ivory.withValues(alpha: 0.38)
                      : Colors.white,
                  disabledBackgroundColor: _CatalogPickerSheetState._card,
                  disabledForegroundColor: AppTheme.ivory.withValues(
                    alpha: 0.38,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                child: Text(label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogSection {
  const _CatalogSection({required this.title, required this.apps});

  final String title;
  final List<CatalogApp> apps;
}
