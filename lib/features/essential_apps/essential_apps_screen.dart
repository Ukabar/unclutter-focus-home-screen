import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/brand/stillscreen_logo.dart';
import '../../core/theme/app_theme.dart';
import '../launcher_routes/launcher_route_dispatcher.dart';
import 'catalog/app_catalog_repository.dart';
import 'catalog/catalog_app.dart';
import 'models/launcher_entry.dart';
import 'persistence/launcher_entry_repository.dart';
import 'widgets/catalog_picker_sheet.dart';
import 'widgets/entry_form_dialog.dart';
import 'widgets/essential_apps_empty_state.dart';
import 'widgets/launcher_entry_tile.dart';
import 'widgets/premium_components.dart';
import 'widgets/status_banner.dart';

class EssentialAppsScreen extends StatefulWidget {
  const EssentialAppsScreen({
    required this.launcherEntryRepository,
    required this.appCatalogRepository,
    this.launcherRouteDispatcher,
    this.onSelectionReset,
    super.key,
  });

  final LauncherEntryRepository launcherEntryRepository;
  final AppCatalogRepository appCatalogRepository;
  final LauncherRouteDispatcher? launcherRouteDispatcher;
  final VoidCallback? onSelectionReset;

  @override
  State<EssentialAppsScreen> createState() => _EssentialAppsScreenState();
}

class _EssentialAppsScreenState extends State<EssentialAppsScreen> {
  List<LauncherEntry> _entries = <LauncherEntry>[];
  List<CatalogApp> _catalogApps = <CatalogApp>[];
  int _selectedTab = 0;
  int _guideStep = 0;
  String _widgetFamily = 'Medium';
  bool _isLoading = true;
  String? _warning;
  String? _error;
  StreamSubscription<LauncherRouteDispatchResult>? _launcherRouteSubscription;
  LauncherRouteDispatcher? _startedLauncherRouteDispatcher;
  bool _hasPendingSetupRequest = false;

  @override
  void initState() {
    super.initState();
    _attachLauncherRouteDispatcher();
    _loadData();
  }

  @override
  void didUpdateWidget(EssentialAppsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.launcherEntryRepository != widget.launcherEntryRepository ||
        oldWidget.appCatalogRepository != widget.appCatalogRepository) {
      _loadData();
    }
    if (oldWidget.launcherRouteDispatcher != widget.launcherRouteDispatcher) {
      _attachLauncherRouteDispatcher();
    }
  }

  @override
  void dispose() {
    _launcherRouteSubscription?.cancel();
    super.dispose();
  }

  void _attachLauncherRouteDispatcher() {
    _launcherRouteSubscription?.cancel();
    final LauncherRouteDispatcher? dispatcher = widget.launcherRouteDispatcher;
    if (dispatcher == null) {
      return;
    }

    _launcherRouteSubscription = dispatcher.results.listen(
      _handleLauncherRouteResult,
    );

    if (_startedLauncherRouteDispatcher != dispatcher) {
      _startedLauncherRouteDispatcher = dispatcher;
      unawaited(dispatcher.start());
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final LauncherLoadResult listResult = await widget.launcherEntryRepository
          .loadEntries();
      final CatalogLoadResult catalogResult = await widget.appCatalogRepository
          .loadCatalog();

      if (!mounted) {
        return;
      }

      setState(() {
        _entries = listResult.entries;
        _catalogApps = catalogResult.apps;
        _warning = listResult.warning ?? catalogResult.warning;
        _isLoading = false;
      });

      if (listResult.entries.isNotEmpty) {
        await _syncSharedDataAfterLoad();
      }

      await _openPendingSetupRequestIfReady();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'The list could not be loaded.';
        _warning = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLauncherRouteResult(
    LauncherRouteDispatchResult result,
  ) async {
    if (!mounted) {
      return;
    }

    if (result.status == LauncherRouteDispatchStatus.setupRequested) {
      _hasPendingSetupRequest = true;
      await _openPendingSetupRequestIfReady();
      return;
    }

    final String? userMessage = result.userMessage;
    if (userMessage == null) {
      return;
    }

    setState(() {
      _warning = userMessage;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(userMessage)));
  }

  Future<void> _openPendingSetupRequestIfReady() async {
    if (!_hasPendingSetupRequest || _isLoading || !mounted) {
      return;
    }

    _hasPendingSetupRequest = false;
    setState(() => _selectedTab = 1);
    await _openAddSheet();
  }

  Future<void> _syncSharedDataAfterLoad() async {
    try {
      await widget.launcherEntryRepository.syncCurrentEntries();
    } on SharedLauncherSyncException {
      if (!mounted) {
        return;
      }

      setState(() {
        _warning = _syncWarningMessage();
      });
    }
  }

  Future<void> _openAddSheet() async {
    final List<LauncherEntry>? selectedEntries =
        await showModalBottomSheet<List<LauncherEntry>>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return CatalogPickerSheet(
              apps: _catalogApps,
              selectedEntries: _entries,
              onManualEntry: _promptEntryForm,
            );
          },
        );

    if (selectedEntries != null) {
      await _replaceEntries(selectedEntries);
    }
  }

  Future<void> _openEntryForm({LauncherEntry? entry}) async {
    final LauncherEntry? result = await _promptEntryForm(entry: entry);
    if (result == null) {
      return;
    }

    if (entry == null) {
      await _addEntry(result);
    } else {
      await _updateEntry(result);
    }
  }

  Future<LauncherEntry?> _promptEntryForm({LauncherEntry? entry}) {
    return showDialog<LauncherEntry>(
      context: context,
      builder: (BuildContext context) => EntryFormDialog(entry: entry),
    );
  }

  Future<void> _addEntry(LauncherEntry entry) async {
    await _runMutation(() => widget.launcherEntryRepository.addEntry(entry));
  }

  Future<void> _replaceEntries(List<LauncherEntry> entries) async {
    await _runMutation(() async {
      await widget.launcherEntryRepository.saveEntries(entries);
      return (await widget.launcherEntryRepository.loadEntries()).entries;
    });
  }

  Future<void> _updateEntry(LauncherEntry entry) async {
    await _runMutation(() => widget.launcherEntryRepository.updateEntry(entry));
  }

  Future<void> _deleteEntry(LauncherEntry entry) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Remove app?'),
              content: Text('${entry.name} will be removed from your list.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    await _runMutation(
      () => widget.launcherEntryRepository.deleteEntry(entry.id),
    );
  }

  Future<void> _reorderEntries(int oldIndex, int newIndex) async {
    await _runMutation(
      () => widget.launcherEntryRepository.reorderEntries(oldIndex, newIndex),
    );
  }

  Future<void> _moveEntryUp(int index) async {
    if (index <= 0) {
      return;
    }
    await _reorderEntries(index, index - 1);
  }

  Future<void> _moveEntryDown(int index) async {
    if (index >= _entries.length - 1) {
      return;
    }
    await _reorderEntries(index, index + 1);
  }

  Future<void> _runMutation(
    Future<List<LauncherEntry>> Function() operation,
  ) async {
    try {
      final List<LauncherEntry> nextEntries = await operation();

      if (!mounted) {
        return;
      }

      setState(() {
        _entries = nextEntries;
        _error = null;
      });
    } on SharedLauncherSyncException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _entries = error.entries;
        _warning = _syncWarningMessage();
        _error = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_syncWarningMessage())));
    } on LauncherEntryException catch (error) {
      _showError(error.message);
    } on Object catch (error) {
      setState(() {
        _warning = error.toString();
      });
      _showError('The change could not be saved.');
    }
  }

  String _syncWarningMessage() {
    return 'Saved locally, but widget sync is not available yet.';
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _error = message;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffoldBand(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: <Widget>[
                    if (_warning != null)
                      StatusBanner(
                        message: _warning!,
                        icon: CupertinoIcons.info_circle,
                      ),
                    if (_error != null)
                      StatusBanner(
                        message: _error!,
                        icon: CupertinoIcons.exclamationmark_triangle,
                        isError: true,
                      ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeOutCubic,
                        child: _buildTab(),
                      ),
                    ),
                  ],
                ),
        ),
        bottomNavigationBar: _BottomNav(
          selectedIndex: _selectedTab,
          onChanged: (int index) => setState(() => _selectedTab = index),
        ),
      ),
    );
  }

  Widget _buildTab() {
    return switch (_selectedTab) {
      0 => _HomeTab(
        key: const ValueKey<String>('home'),
        entries: _entries,
        onAddPressed: _openAddSheet,
        onEditPressed: () => setState(() => _selectedTab = 1),
        onWidgetPressed: () => setState(() => _selectedTab = 2),
        onGuidePressed: () => setState(() => _selectedTab = 3),
      ),
      1 => _AppsTab(
        key: const ValueKey<String>('apps'),
        entries: _entries,
        onAddPressed: _openAddSheet,
        onEditEntry: _openEntryForm,
        onDeleteEntry: _deleteEntry,
        onMoveEntryUp: _moveEntryUp,
        onMoveEntryDown: _moveEntryDown,
        onReorderEntries: _reorderEntries,
      ),
      2 => _WidgetPreviewTab(
        key: const ValueKey<String>('widget'),
        entries: _entries,
        family: _widgetFamily,
        onFamilyChanged: (String value) =>
            setState(() => _widgetFamily = value),
      ),
      3 => _SetupGuideTab(
        key: const ValueKey<String>('guide'),
        step: _guideStep,
        onStepChanged: (int value) => setState(() => _guideStep = value),
      ),
      _ => _SettingsTab(
        key: const ValueKey<String>('settings'),
        entryCount: _entries.length,
        onReset: () async {
          await widget.launcherEntryRepository.saveEntries(<LauncherEntry>[]);
          await _loadData();
          widget.onSelectionReset?.call();
        },
      ),
    };
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.entries,
    required this.onAddPressed,
    required this.onEditPressed,
    required this.onWidgetPressed,
    required this.onGuidePressed,
    super.key,
  });

  final List<LauncherEntry> entries;
  final VoidCallback onAddPressed;
  final VoidCallback onEditPressed;
  final VoidCallback onWidgetPressed;
  final VoidCallback onGuidePressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: <Widget>[
        Row(
          children: <Widget>[
            const StillscreenLogo(size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Stillscreen',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Essential apps',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        PremiumCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entries.isEmpty
                    ? 'Make your first screen quiet.'
                    : 'Your quiet launcher is ready.',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                entries.isEmpty
                    ? 'Choose only the apps that support the day you want.'
                    : '${entries.length} selected apps are ordered for the Widget and launcher routes.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  PremiumActionButton(
                    keyName: entries.isEmpty
                        ? 'empty-add-app-button'
                        : 'add-app-button',
                    label: 'Add Apps',
                    icon: CupertinoIcons.plus,
                    onPressed: onAddPressed,
                    isPrimary: true,
                  ),
                  PremiumActionButton(
                    label: 'Edit',
                    icon: CupertinoIcons.slider_horizontal_3,
                    onPressed: onEditPressed,
                  ),
                  PremiumActionButton(
                    label: 'Widget Preview',
                    icon: CupertinoIcons.rectangle_grid_2x2,
                    onPressed: onWidgetPressed,
                  ),
                  PremiumActionButton(
                    label: 'Setup Guide',
                    icon: CupertinoIcons.map,
                    onPressed: onGuidePressed,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        PremiumSectionHeader(
          title: 'Selected apps',
          subtitle: 'A restrained preview of the list your Widget reads.',
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  CupertinoIcons.square_grid_2x2,
                  color: theme.colorScheme.primary,
                  size: 34,
                ),
                const SizedBox(height: 14),
                Text(
                  'Choose what deserves a place here.',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add up to 12 trusted apps. They stay local and sync to the Widget through App Groups when available.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                PremiumActionButton(
                  keyName: 'add-first-app-button',
                  label: 'Add first app',
                  icon: CupertinoIcons.plus,
                  onPressed: onAddPressed,
                  isPrimary: true,
                ),
              ],
            ),
          )
        else
          PremiumCard(
            child: Column(
              children: entries.take(6).map((LauncherEntry entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: <Widget>[
                      AppGlyph(name: entry.name),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          entry.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        CupertinoIcons.arrow_up_right,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _AppsTab extends StatelessWidget {
  const _AppsTab({
    required this.entries,
    required this.onAddPressed,
    required this.onEditEntry,
    required this.onDeleteEntry,
    required this.onMoveEntryUp,
    required this.onMoveEntryDown,
    required this.onReorderEntries,
    super.key,
  });

  final List<LauncherEntry> entries;
  final VoidCallback onAddPressed;
  final Future<void> Function({LauncherEntry? entry}) onEditEntry;
  final Future<void> Function(LauncherEntry entry) onDeleteEntry;
  final Future<void> Function(int index) onMoveEntryUp;
  final Future<void> Function(int index) onMoveEntryDown;
  final Future<void> Function(int oldIndex, int newIndex) onReorderEntries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: PremiumSectionHeader(
            title: 'Essential apps',
            subtitle: 'Search, add, remove, and drag to set Widget order.',
            action: SelectedCounter(count: entries.length),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: PremiumActionButton(
              keyName: 'add-app-button',
              label: 'Add Apps',
              icon: CupertinoIcons.plus,
              onPressed: onAddPressed,
              isPrimary: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: entries.isEmpty
              ? EssentialAppsEmptyState(onAddPressed: onAddPressed)
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  itemCount: entries.length,
                  onReorderItem: (int oldIndex, int newIndex) {
                    unawaited(onReorderEntries(oldIndex, newIndex));
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final LauncherEntry entry = entries[index];
                    return LauncherEntryTile(
                      key: ValueKey<String>(entry.id),
                      entry: entry,
                      index: index,
                      isFirst: index == 0,
                      isLast: index == entries.length - 1,
                      onEdit: () => unawaited(onEditEntry(entry: entry)),
                      onDelete: () => unawaited(onDeleteEntry(entry)),
                      onMoveUp: () => unawaited(onMoveEntryUp(index)),
                      onMoveDown: () => unawaited(onMoveEntryDown(index)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _WidgetPreviewTab extends StatelessWidget {
  const _WidgetPreviewTab({
    required this.entries,
    required this.family,
    required this.onFamilyChanged,
    super.key,
  });

  final List<LauncherEntry> entries;
  final String family;
  final ValueChanged<String> onFamilyChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: <Widget>[
        const PremiumSectionHeader(
          title: 'Widget Preview',
          subtitle: 'A live preview using the same selected app order.',
        ),
        const SizedBox(height: 18),
        SegmentedButton<String>(
          segments: const <ButtonSegment<String>>[
            ButtonSegment<String>(value: 'Small', label: Text('Small')),
            ButtonSegment<String>(value: 'Medium', label: Text('Medium')),
            ButtonSegment<String>(value: 'Large', label: Text('Large')),
          ],
          selected: <String>{family},
          onSelectionChanged: (Set<String> value) {
            onFamilyChanged(value.single);
          },
        ),
        const SizedBox(height: 18),
        WidgetFramePreview(entries: entries, family: family),
        const SizedBox(height: 18),
        PremiumCard(
          child: Text(
            'WidgetKit reads App Group data locally. Changes reload timelines after a successful shared write.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SetupGuideTab extends StatelessWidget {
  const _SetupGuideTab({
    required this.step,
    required this.onStepChanged,
    super.key,
  });

  final int step;
  final ValueChanged<int> onStepChanged;

  static const List<_GuideStep> _steps = <_GuideStep>[
    _GuideStep(
      title: 'Add the Widget',
      body:
          'Touch and hold the Home Screen, choose Widgets, then add Stillscreen.',
      icon: CupertinoIcons.rectangle_grid_2x2,
    ),
    _GuideStep(
      title: 'Choose a quiet background',
      body: 'A plain wallpaper makes the selected apps feel intentional.',
      icon: CupertinoIcons.photo,
    ),
    _GuideStep(
      title: 'Hide noisy pages',
      body: 'Move non-essential apps away from the first Home Screen.',
      icon: CupertinoIcons.eye_slash,
    ),
    _GuideStep(
      title: 'Enable Focus Mode',
      body: 'Pair the Widget with iOS Focus for a calmer context.',
      icon: CupertinoIcons.moon,
    ),
    _GuideStep(
      title: 'Finish setup',
      body: 'Return anytime to edit order, preview the Widget, or add apps.',
      icon: CupertinoIcons.check_mark_circled,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _GuideStep current = _steps[step];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: <Widget>[
        const PremiumSectionHeader(
          title: 'Setup Guide',
          subtitle: 'Five calm steps to make iOS feel less crowded.',
        ),
        const SizedBox(height: 18),
        PremiumCard(
          padding: const EdgeInsets.all(26),
          child: Column(
            children: <Widget>[
              Icon(current.icon, size: 58, color: AppTheme.accent),
              const SizedBox(height: 24),
              Text(
                current.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                current.body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(value: (step + 1) / _steps.length),
              const SizedBox(height: 22),
              Row(
                children: <Widget>[
                  Expanded(
                    child: PremiumActionButton(
                      label: 'Previous',
                      icon: CupertinoIcons.arrow_left,
                      onPressed: step == 0
                          ? null
                          : () => onStepChanged(step - 1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PremiumActionButton(
                      label: step == _steps.length - 1 ? 'Done' : 'Next',
                      icon: CupertinoIcons.arrow_right,
                      onPressed: step == _steps.length - 1
                          ? null
                          : () => onStepChanged(step + 1),
                      isPrimary: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.entryCount,
    required this.onReset,
    super.key,
  });

  final int entryCount;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: <Widget>[
        const PremiumSectionHeader(
          title: 'Settings',
          subtitle: 'Fine-tune the look without adding noise.',
        ),
        const SizedBox(height: 18),
        _SettingsRow(
          icon: CupertinoIcons.paintbrush,
          title: 'Theme',
          value: 'System dark',
        ),
        _SettingsRow(
          icon: CupertinoIcons.drop,
          title: 'Accent Color',
          value: 'Quiet Blue',
        ),
        _SettingsRow(
          icon: CupertinoIcons.rectangle_grid_2x2,
          title: 'Widget Style',
          value: '$entryCount apps selected',
        ),
        _SettingsRow(
          icon: CupertinoIcons.lock_shield,
          title: 'Privacy',
          value: 'Local only',
        ),
        _SettingsRow(
          icon: CupertinoIcons.info_circle,
          title: 'About',
          value: 'Stillscreen: Focus Launcher',
        ),
        const SizedBox(height: 18),
        PremiumActionButton(
          label: 'Reset',
          icon: CupertinoIcons.arrow_counterclockwise,
          onPressed: onReset,
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onChanged,
      backgroundColor: AppTheme.ink.withValues(alpha: 0.96),
      indicatorColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.16),
      destinations: const <NavigationDestination>[
        NavigationDestination(
          icon: Icon(CupertinoIcons.house),
          selectedIcon: Icon(CupertinoIcons.house_fill),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(CupertinoIcons.square_grid_2x2),
          selectedIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
          label: 'Apps',
        ),
        NavigationDestination(
          icon: Icon(CupertinoIcons.rectangle_grid_2x2),
          selectedIcon: Icon(CupertinoIcons.rectangle_grid_2x2_fill),
          label: 'Widget',
        ),
        NavigationDestination(
          icon: Icon(CupertinoIcons.map),
          selectedIcon: Icon(CupertinoIcons.map_fill),
          label: 'Guide',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}

class _GuideStep {
  const _GuideStep({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;
}
