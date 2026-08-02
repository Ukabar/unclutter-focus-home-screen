import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/brand/stillscreen_logo.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../ads/ad_banner.dart';
import '../ads/ads_controller.dart';
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
    this.themeChoice = AppDefaults.defaultThemeChoice,
    this.accentChoice = AppDefaults.defaultAccentChoice,
    this.onThemeChoiceChanged,
    this.onAccentChoiceChanged,
    this.onSettingsReset,
    this.adsController,
    super.key,
  });

  final LauncherEntryRepository launcherEntryRepository;
  final AppCatalogRepository appCatalogRepository;
  final LauncherRouteDispatcher? launcherRouteDispatcher;
  final VoidCallback? onSelectionReset;
  final AppThemeChoice themeChoice;
  final AppAccentChoice accentChoice;
  final ValueChanged<AppThemeChoice>? onThemeChoiceChanged;
  final ValueChanged<AppAccentChoice>? onAccentChoiceChanged;
  final Future<void> Function()? onSettingsReset;
  final AdsController? adsController;

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
  bool _isResetting = false;
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

      assert(() {
        debugPrint('Essential apps load failed: $error');
        return true;
      }());
      setState(() {
        _error = 'The list could not be loaded.';
        _warning = 'Your apps could not be loaded right now.';
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
    } on SharedLauncherSyncException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _warning = error.message;
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
      await widget.adsController?.recordMeaningfulActionCompleted(
        resultVisible: true,
      );
    } on SharedLauncherSyncException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _entries = error.entries;
        _warning = error.message;
        _error = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      await widget.adsController?.recordMeaningfulActionCompleted(
        resultVisible: true,
      );
    } on LauncherEntryException catch (error) {
      _showError(error.message);
    } on Object catch (error) {
      assert(() {
        debugPrint('Essential apps mutation failed: $error');
        return true;
      }());
      setState(() {
        _warning = 'The change could not be saved right now.';
      });
      _showError('The change could not be saved.');
    }
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
                        child: _AdaptiveTabContainer(child: _buildTab()),
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
        adsController: widget.adsController,
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
        themeChoice: widget.themeChoice,
        accentChoice: widget.accentChoice,
        onThemePressed: _showThemeSelector,
        onAccentPressed: _showAccentSelector,
        onPrivacyPressed: _showPrivacyInfo,
        onAboutPressed: _showAboutInfo,
        onReset: _resetSelectedApps,
        isResetting: _isResetting,
      ),
    };
  }

  Future<void> _showThemeSelector() async {
    final AppThemeChoice? choice = await showModalBottomSheet<AppThemeChoice>(
      context: context,
      builder: (BuildContext context) {
        return _SettingsSheet(
          title: 'Theme',
          children: AppThemeChoice.values.map((AppThemeChoice choice) {
            return _SheetOption(
              label: choice.label,
              selected: choice == widget.themeChoice,
              onTap: () => Navigator.of(context).pop(choice),
            );
          }).toList(),
        );
      },
    );

    if (choice != null) {
      widget.onThemeChoiceChanged?.call(choice);
    }
  }

  Future<void> _showAccentSelector() async {
    final AppAccentChoice? choice = await showModalBottomSheet<AppAccentChoice>(
      context: context,
      builder: (BuildContext context) {
        return _SettingsSheet(
          title: 'Accent Color',
          children: AppAccentChoice.values.map((AppAccentChoice choice) {
            return _SheetOption(
              label: choice.label,
              selected: choice == widget.accentChoice,
              leading: DecoratedBox(
                decoration: BoxDecoration(
                  color: choice.color,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 18),
              ),
              onTap: () => Navigator.of(context).pop(choice),
            );
          }).toList(),
        );
      },
    );

    if (choice != null) {
      widget.onAccentChoiceChanged?.call(choice);
    }
  }

  void _showPrivacyInfo() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return const _SettingsSheet(
          title: 'Privacy',
          children: <Widget>[
            _SheetBodyText(
              'No tracking, no account, no contacts, no location, no notifications, and no installed-app scanning are required for Stillscreen settings.',
            ),
            SizedBox(height: 10),
            _SheetBodyText(
              'Your selected apps stay on this device. On iOS, the Widget reads a local App Group copy so the Home Screen can update without an account.',
            ),
            SizedBox(height: 10),
            _SheetBodyText(
              'This build includes an advertising SDK. Stillscreen settings are still stored locally and are not used for analytics or accounts.',
            ),
          ],
        );
      },
    );
  }

  void _showAboutInfo() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return _SettingsSheet(
          title: 'About',
          children: <Widget>[
            const _SheetInfoRow(label: 'App name', value: 'Stillscreen'),
            const _SheetInfoRow(
              label: 'Display name',
              value: AppDefaults.aboutDisplayName,
            ),
            const _SheetInfoRow(
              label: 'Version',
              value: AppDefaults.appVersion,
            ),
            const _SheetInfoRow(label: 'Build', value: AppDefaults.buildNumber),
            const _SheetInfoRow(
              label: 'Bundle ID',
              value: AppDefaults.bundleIdentifier,
            ),
            const _SheetInfoRow(
              label: 'Privacy',
              value: 'Local settings and local Widget App Group storage',
            ),
            _SheetOption(
              label: 'Licenses',
              onTap: () {
                Navigator.of(context).pop();
                showLicensePage(
                  context: context,
                  applicationName: AppDefaults.aboutDisplayName,
                  applicationVersion:
                      '${AppDefaults.appVersion} (${AppDefaults.buildNumber})',
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetSelectedApps() async {
    if (_isResetting) {
      return;
    }

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Reset app?'),
              content: const Text(
                'This restores Dark theme, Dusk accent, local-only privacy, and removes your selected apps. Onboarding will not be reset.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Reset app'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() => _isResetting = true);

    try {
      await widget.onSettingsReset?.call();
      await widget.launcherEntryRepository.saveEntries(<LauncherEntry>[]);
      await _loadData();
      widget.onSelectionReset?.call();
    } on SharedLauncherSyncException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = error.entries;
        _warning = error.message;
      });
      widget.onSelectionReset?.call();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      assert(() {
        debugPrint('Settings reset failed: $error');
        return true;
      }());
      _showError('Settings could not be reset right now.');
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.entries,
    required this.onAddPressed,
    this.adsController,
    super.key,
  });

  final List<LauncherEntry> entries;
  final VoidCallback onAddPressed;
  final AdsController? adsController;

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
        if (adsController != null) ...<Widget>[
          const SizedBox(height: 16),
          RemoteBannerAd(controller: adsController!),
        ],
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
              Icon(current.icon, size: 58, color: theme.colorScheme.primary),
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
    required this.themeChoice,
    required this.accentChoice,
    required this.onThemePressed,
    required this.onAccentPressed,
    required this.onPrivacyPressed,
    required this.onAboutPressed,
    required this.onReset,
    required this.isResetting,
    super.key,
  });

  final AppThemeChoice themeChoice;
  final AppAccentChoice accentChoice;
  final VoidCallback onThemePressed;
  final VoidCallback onAccentPressed;
  final VoidCallback onPrivacyPressed;
  final VoidCallback onAboutPressed;
  final VoidCallback onReset;
  final bool isResetting;

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
          value: themeChoice.label,
          onTap: onThemePressed,
        ),
        _SettingsRow(
          icon: CupertinoIcons.drop,
          title: 'Accent Color',
          value: accentChoice.label,
          onTap: onAccentPressed,
        ),
        _SettingsRow(
          icon: CupertinoIcons.rectangle_grid_2x2,
          title: 'Widget Style',
          value: AppDefaults.defaultWidgetStyle.label,
          enabled: AppDefaults.defaultWidgetStyle.enabled,
        ),
        _SettingsRow(
          icon: CupertinoIcons.lock_shield,
          title: 'Privacy',
          value: AppDefaults.defaultPrivacy.label,
          onTap: onPrivacyPressed,
        ),
        _SettingsRow(
          icon: CupertinoIcons.info_circle,
          title: 'About',
          value: AppDefaults.aboutDisplayName,
          onTap: onAboutPressed,
        ),
        const SizedBox(height: 18),
        PremiumActionButton(
          label: isResetting ? 'Resetting...' : 'Reset app',
          icon: CupertinoIcons.arrow_counterclockwise,
          onPressed: isResetting ? null : onReset,
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
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool interactive = enabled && onTap != null;
    final Color contentColor = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.58);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: interactive,
        enabled: enabled,
        label: enabled ? '$title, $value' : '$title, $value, unavailable',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: interactive ? onTap : null,
            child: PremiumCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  Icon(
                    icon,
                    color: enabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.46,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: contentColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (interactive) ...<Widget>[
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdaptiveTabContainer extends StatelessWidget {
  const _AdaptiveTabContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool tablet = constraints.maxWidth >= 600;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: tablet ? 700 : constraints.maxWidth,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.leading,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    leading!,
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetBodyText extends StatelessWidget {
  const _SheetBodyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.45,
      ),
    );
  }
}

class _SheetInfoRow extends StatelessWidget {
  const _SheetInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
