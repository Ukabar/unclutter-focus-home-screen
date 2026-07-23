import 'dart:async';

import '../essential_apps/models/launcher_entry.dart';
import '../essential_apps/persistence/launcher_entry_repository.dart';
import '../essential_apps/validation/launch_url_validator.dart';
import 'launcher_route.dart';
import 'launcher_route_source.dart';
import 'launcher_target_opener.dart';

class LauncherRouteDispatcher {
  LauncherRouteDispatcher({
    required LauncherEntryRepository launcherEntryRepository,
    required LauncherRouteSource routeSource,
    required LauncherTargetOpener targetOpener,
    DateTime Function()? now,
    Duration duplicateWindow = const Duration(seconds: 2),
  }) : this._(
         launcherEntryRepository,
         routeSource,
         targetOpener,
         now ?? DateTime.now,
         duplicateWindow,
       );

  LauncherRouteDispatcher._(
    this._launcherEntryRepository,
    this._routeSource,
    this._targetOpener,
    this._now,
    this.duplicateWindow,
  );

  final LauncherEntryRepository _launcherEntryRepository;
  final LauncherRouteSource _routeSource;
  final LauncherTargetOpener _targetOpener;
  final DateTime Function() _now;
  final Duration duplicateWindow;
  final StreamController<LauncherRouteDispatchResult> _results =
      StreamController<LauncherRouteDispatchResult>.broadcast();

  StreamSubscription<String>? _routeSubscription;
  bool _started = false;
  String? _lastRouteKey;
  DateTime? _lastRouteAt;

  Stream<LauncherRouteDispatchResult> get results => _results.stream;

  Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;
    _routeSubscription = _routeSource.routes.listen(dispatchRawRoute);
    await dispatchRawRoute(await _routeSource.takeInitialRoute());
  }

  Future<LauncherRouteDispatchResult?> dispatchRawRoute(
    String? rawRoute,
  ) async {
    if (rawRoute == null || rawRoute.trim().isEmpty) {
      return null;
    }

    final LauncherRouteDispatchResult result = await _dispatchRawRoute(
      rawRoute,
    );
    _results.add(result);
    return result;
  }

  Future<void> dispose() async {
    await _routeSubscription?.cancel();
    await _results.close();
  }

  Future<LauncherRouteDispatchResult> _dispatchRawRoute(String rawRoute) async {
    final LauncherRouteParseResult parseResult = LauncherRoute.parse(rawRoute);
    if (parseResult.status != LauncherRouteParseStatus.valid) {
      return LauncherRouteDispatchResult.fromParseStatus(parseResult.status);
    }

    final LauncherRoute route = parseResult.route!;
    final String routeKey = rawRoute.trim();
    if (_isDuplicate(routeKey)) {
      return const LauncherRouteDispatchResult(
        status: LauncherRouteDispatchStatus.duplicateIgnored,
      );
    }

    _markProcessed(routeKey);

    if (route.kind == LauncherRouteKind.setup) {
      return const LauncherRouteDispatchResult(
        status: LauncherRouteDispatchStatus.setupRequested,
      );
    }

    final String entryId = route.entryId!;
    final LauncherLoadResult loadResult = await _launcherEntryRepository
        .loadEntries();
    final LauncherEntry? entry = _findEntry(loadResult.entries, entryId);

    if (entry == null) {
      return const LauncherRouteDispatchResult(
        status: LauncherRouteDispatchStatus.entryNotFound,
        userMessage:
            'That shortcut is no longer in your list. Open the app to refresh the widget.',
      );
    }

    if (LaunchUrlValidator.validate(entry.launchUrl) != null) {
      return const LauncherRouteDispatchResult(
        status: LauncherRouteDispatchStatus.unsafeTargetRejected,
        userMessage:
            'This app could not be opened. Check that its launch link is still valid.',
      );
    }

    final bool opened = await _targetOpener.open(entry.launchUrl);
    if (!opened) {
      return const LauncherRouteDispatchResult(
        status: LauncherRouteDispatchStatus.targetLaunchFailed,
        userMessage:
            'This app could not be opened. Check that it is installed and that its launch link is still valid.',
      );
    }

    return const LauncherRouteDispatchResult(
      status: LauncherRouteDispatchStatus.opened,
    );
  }

  LauncherEntry? _findEntry(List<LauncherEntry> entries, String entryId) {
    for (final LauncherEntry entry in entries) {
      if (entry.id == entryId) {
        return entry;
      }
    }
    return null;
  }

  bool _isDuplicate(String routeKey) {
    final DateTime now = _now();
    final DateTime? lastRouteAt = _lastRouteAt;
    return _lastRouteKey == routeKey &&
        lastRouteAt != null &&
        now.difference(lastRouteAt) <= duplicateWindow;
  }

  void _markProcessed(String routeKey) {
    _lastRouteKey = routeKey;
    _lastRouteAt = _now();
  }
}

class LauncherRouteDispatchResult {
  const LauncherRouteDispatchResult({required this.status, this.userMessage});

  factory LauncherRouteDispatchResult.fromParseStatus(
    LauncherRouteParseStatus status,
  ) {
    switch (status) {
      case LauncherRouteParseStatus.missingId:
        return const LauncherRouteDispatchResult(
          status: LauncherRouteDispatchStatus.missingId,
          userMessage: 'That widget shortcut could not be read.',
        );
      case LauncherRouteParseStatus.invalidId:
        return const LauncherRouteDispatchResult(
          status: LauncherRouteDispatchStatus.invalidId,
          userMessage: 'That widget shortcut is not valid.',
        );
      case LauncherRouteParseStatus.invalid:
      case LauncherRouteParseStatus.valid:
        return const LauncherRouteDispatchResult(
          status: LauncherRouteDispatchStatus.invalidRoute,
          userMessage: 'That widget shortcut is not valid.',
        );
    }
  }

  final LauncherRouteDispatchStatus status;
  final String? userMessage;
}

enum LauncherRouteDispatchStatus {
  opened,
  setupRequested,
  duplicateIgnored,
  invalidRoute,
  missingId,
  invalidId,
  entryNotFound,
  unsafeTargetRejected,
  targetLaunchFailed,
}
