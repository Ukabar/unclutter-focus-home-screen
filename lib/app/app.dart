import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../features/essential_apps/catalog/app_catalog_repository.dart';
import '../features/essential_apps/catalog/catalog_app.dart';
import '../features/essential_apps/essential_apps_screen.dart';
import '../features/essential_apps/models/launcher_entry.dart';
import '../features/essential_apps/persistence/launcher_entry_repository.dart';
import '../features/essential_apps/persistence/launcher_entry_store.dart';
import '../features/essential_apps/shared/shared_launcher_bridge.dart';
import '../features/essential_apps/shared/shared_launcher_synchronizer.dart';
import '../features/essential_apps/widgets/catalog_picker_sheet.dart';
import '../features/essential_apps/widgets/entry_form_dialog.dart';
import '../features/launcher_routes/launcher_route_dispatcher.dart';
import '../features/launcher_routes/launcher_route_source.dart';
import '../features/launcher_routes/launcher_target_opener.dart';
import 'onboarding_screen.dart';

class StillscreenFocusLauncherApp extends StatefulWidget {
  const StillscreenFocusLauncherApp({
    super.key,
    this.launcherEntryRepository,
    this.appCatalogRepository,
    this.launcherRouteDispatcher,
    this.showOnboarding = true,
  });

  final LauncherEntryRepository? launcherEntryRepository;
  final AppCatalogRepository? appCatalogRepository;
  final LauncherRouteDispatcher? launcherRouteDispatcher;
  final bool showOnboarding;

  @override
  State<StillscreenFocusLauncherApp> createState() =>
      _StillscreenFocusLauncherAppState();
}

class _StillscreenFocusLauncherAppState
    extends State<StillscreenFocusLauncherApp> {
  static const String _onboardingKey = 'stillscreen_onboarding_complete_v1';

  late LauncherEntryRepository _launcherEntryRepository;
  late AppCatalogRepository _appCatalogRepository;
  late LauncherRouteDispatcher _launcherRouteDispatcher;
  bool _isCheckingOnboarding = true;
  bool _showOnboarding = false;
  bool _showInitialPicker = false;
  String? _startupWarning;

  @override
  void initState() {
    super.initState();
    _configureDependencies();
    _loadOnboardingState();
  }

  @override
  void didUpdateWidget(StillscreenFocusLauncherApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.launcherEntryRepository != widget.launcherEntryRepository ||
        oldWidget.appCatalogRepository != widget.appCatalogRepository ||
        oldWidget.launcherRouteDispatcher != widget.launcherRouteDispatcher) {
      _configureDependencies();
      _loadOnboardingState();
    }
    if (oldWidget.showOnboarding != widget.showOnboarding) {
      _loadOnboardingState();
    }
  }

  Future<void> _loadOnboardingState() async {
    if (!widget.showOnboarding) {
      setState(() {
        _isCheckingOnboarding = false;
        _showOnboarding = false;
        _showInitialPicker = false;
        _startupWarning = null;
      });
      return;
    }

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final bool onboardingCompleted =
        preferences.getBool(_onboardingKey) ?? false;
    final LauncherLoadResult entriesResult = await _launcherEntryRepository
        .loadEntries();
    if (!mounted) {
      return;
    }

    setState(() {
      _isCheckingOnboarding = false;
      _showOnboarding = !onboardingCompleted;
      _showInitialPicker = onboardingCompleted && entriesResult.entries.isEmpty;
      _startupWarning = entriesResult.warning;
    });
  }

  Future<void> _finishOnboarding() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final bool saved = await preferences.setBool(_onboardingKey, true);
    if (!mounted) {
      return;
    }
    if (!saved) {
      setState(() {
        _startupWarning = 'The onboarding state could not be saved.';
      });
      return;
    }
    setState(() {
      _showOnboarding = false;
      _showInitialPicker = true;
      _startupWarning = null;
    });
  }

  void _configureDependencies() {
    _launcherEntryRepository =
        widget.launcherEntryRepository ??
        LauncherEntryRepository(
          store: SharedPreferencesLauncherEntryStore(),
          sharedSynchronizer: SharedLauncherSynchronizer(
            bridge: MethodChannelSharedLauncherBridge(),
          ),
        );

    _appCatalogRepository =
        widget.appCatalogRepository ?? const AssetAppCatalogRepository();

    _launcherRouteDispatcher =
        widget.launcherRouteDispatcher ??
        LauncherRouteDispatcher(
          launcherEntryRepository: _launcherEntryRepository,
          routeSource: MethodChannelLauncherRouteSource(),
          targetOpener: const UrlLauncherTargetOpener(),
        );
  }

  Future<void> _completeInitialSelection(List<LauncherEntry> entries) async {
    try {
      await _launcherEntryRepository.saveEntries(entries);
    } on SharedLauncherSyncException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _startupWarning = error.message;
        _showInitialPicker = false;
      });
      return;
    } on LauncherEntryException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _startupWarning = error.message;
      });
      return;
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _startupWarning = error.toString();
      });
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _showInitialPicker = false;
      _startupWarning = null;
    });
  }

  void _openInitialPickerAfterReset() {
    setState(() {
      _showInitialPicker = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stillscreen: Focus Launcher',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: _isCheckingOnboarding
          ? const _LaunchLoadingScreen()
          : _showOnboarding
          ? OnboardingScreen(onFinish: _finishOnboarding)
          : _showInitialPicker
          ? _InitialAppPickerScreen(
              launcherEntryRepository: _launcherEntryRepository,
              appCatalogRepository: _appCatalogRepository,
              warning: _startupWarning,
              onComplete: _completeInitialSelection,
            )
          : EssentialAppsScreen(
              launcherEntryRepository: _launcherEntryRepository,
              appCatalogRepository: _appCatalogRepository,
              launcherRouteDispatcher: _launcherRouteDispatcher,
              onSelectionReset: _openInitialPickerAfterReset,
            ),
    );
  }
}

class _LaunchLoadingScreen extends StatelessWidget {
  const _LaunchLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _InitialAppPickerScreen extends StatefulWidget {
  const _InitialAppPickerScreen({
    required this.launcherEntryRepository,
    required this.appCatalogRepository,
    required this.onComplete,
    this.warning,
  });

  final LauncherEntryRepository launcherEntryRepository;
  final AppCatalogRepository appCatalogRepository;
  final Future<void> Function(List<LauncherEntry> entries) onComplete;
  final String? warning;

  @override
  State<_InitialAppPickerScreen> createState() =>
      _InitialAppPickerScreenState();
}

class _InitialAppPickerScreenState extends State<_InitialAppPickerScreen> {
  List<CatalogApp> _catalogApps = <CatalogApp>[];
  List<LauncherEntry> _selectedEntries = <LauncherEntry>[];
  bool _isLoading = true;
  String? _warning;

  @override
  void initState() {
    super.initState();
    _warning = widget.warning;
    _loadData();
  }

  @override
  void didUpdateWidget(_InitialAppPickerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appCatalogRepository != widget.appCatalogRepository ||
        oldWidget.launcherEntryRepository != widget.launcherEntryRepository) {
      _loadData();
    }
    if (oldWidget.warning != widget.warning) {
      _warning = widget.warning;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final CatalogLoadResult catalogResult = await widget.appCatalogRepository
          .loadCatalog();
      final LauncherLoadResult entriesResult = await widget
          .launcherEntryRepository
          .loadEntries();
      if (!mounted) {
        return;
      }
      setState(() {
        _catalogApps = catalogResult.apps;
        _selectedEntries = entriesResult.entries;
        _warning = entriesResult.warning ?? catalogResult.warning ?? _warning;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _warning = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<LauncherEntry?> _openManualEntry() {
    return showDialog<LauncherEntry>(
      context: context,
      builder: (BuildContext context) => const EntryFormDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _LaunchLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          CatalogPickerSheet(
            apps: _catalogApps,
            selectedEntries: _selectedEntries,
            onManualEntry: _openManualEntry,
            onSelectionComplete: widget.onComplete,
            isFullScreen: true,
          ),
          if (_warning != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _warning!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
