import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/essential_apps/catalog/app_catalog_repository.dart';
import '../features/essential_apps/essential_apps_screen.dart';
import '../features/essential_apps/persistence/launcher_entry_repository.dart';
import '../features/essential_apps/persistence/launcher_entry_store.dart';
import '../features/essential_apps/shared/shared_launcher_bridge.dart';
import '../features/essential_apps/shared/shared_launcher_synchronizer.dart';
import '../features/launcher_routes/launcher_route_dispatcher.dart';
import '../features/launcher_routes/launcher_route_source.dart';
import '../features/launcher_routes/launcher_target_opener.dart';

class DumbphoneHomescreenApp extends StatefulWidget {
  const DumbphoneHomescreenApp({
    super.key,
    this.launcherEntryRepository,
    this.appCatalogRepository,
    this.launcherRouteDispatcher,
  });

  final LauncherEntryRepository? launcherEntryRepository;
  final AppCatalogRepository? appCatalogRepository;
  final LauncherRouteDispatcher? launcherRouteDispatcher;

  @override
  State<DumbphoneHomescreenApp> createState() => _DumbphoneHomescreenAppState();
}

class _DumbphoneHomescreenAppState extends State<DumbphoneHomescreenApp> {
  late LauncherEntryRepository _launcherEntryRepository;
  late LauncherRouteDispatcher _launcherRouteDispatcher;

  @override
  void initState() {
    super.initState();
    _configureDependencies();
  }

  @override
  void didUpdateWidget(DumbphoneHomescreenApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.launcherEntryRepository != widget.launcherEntryRepository ||
        oldWidget.launcherRouteDispatcher != widget.launcherRouteDispatcher) {
      _configureDependencies();
    }
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

    _launcherRouteDispatcher =
        widget.launcherRouteDispatcher ??
        LauncherRouteDispatcher(
          launcherEntryRepository: _launcherEntryRepository,
          routeSource: MethodChannelLauncherRouteSource(),
          targetOpener: const UrlLauncherTargetOpener(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dumbphone Homescreen',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: EssentialAppsScreen(
        launcherEntryRepository: _launcherEntryRepository,
        appCatalogRepository:
            widget.appCatalogRepository ?? const AssetAppCatalogRepository(),
        launcherRouteDispatcher: _launcherRouteDispatcher,
      ),
    );
  }
}
