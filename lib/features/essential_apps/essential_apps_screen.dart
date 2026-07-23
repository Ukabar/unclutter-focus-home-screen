import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/brand/stillscreen_logo.dart';
import 'catalog/app_catalog_repository.dart';
import 'catalog/catalog_app.dart';
import 'models/launcher_entry.dart';
import 'persistence/launcher_entry_repository.dart';
import '../launcher_routes/launcher_route_dispatcher.dart';
import 'widgets/catalog_picker_sheet.dart';
import 'widgets/entry_form_dialog.dart';
import 'widgets/essential_apps_empty_state.dart';
import 'widgets/launcher_entry_tile.dart';
import 'widgets/status_banner.dart';

class EssentialAppsScreen extends StatefulWidget {
  const EssentialAppsScreen({
    required this.launcherEntryRepository,
    required this.appCatalogRepository,
    this.launcherRouteDispatcher,
    super.key,
  });

  final LauncherEntryRepository launcherEntryRepository;
  final AppCatalogRepository appCatalogRepository;
  final LauncherRouteDispatcher? launcherRouteDispatcher;

  @override
  State<EssentialAppsScreen> createState() => _EssentialAppsScreenState();
}

class _EssentialAppsScreenState extends State<EssentialAppsScreen> {
  List<LauncherEntry> _entries = <LauncherEntry>[];
  List<CatalogApp> _catalogApps = <CatalogApp>[];
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
    final CatalogApp? selectedApp = await showModalBottomSheet<CatalogApp>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return CatalogPickerSheet(
          apps: _catalogApps,
          selectedEntries: _entries,
          onManualEntry: () async {
            Navigator.of(context).pop();
            await _openEntryForm();
          },
        );
      },
    );

    if (selectedApp != null) {
      await _addEntry(selectedApp.toLauncherEntry());
    }
  }

  Future<void> _openEntryForm({LauncherEntry? entry}) async {
    final LauncherEntry? result = await showDialog<LauncherEntry>(
      context: context,
      builder: (BuildContext context) => EntryFormDialog(entry: entry),
    );

    if (result == null) {
      return;
    }

    if (entry == null) {
      await _addEntry(result);
    } else {
      await _updateEntry(result);
    }
  }

  Future<void> _addEntry(LauncherEntry entry) async {
    await _runMutation(() => widget.launcherEntryRepository.addEntry(entry));
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
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Center(child: StillscreenLogo(size: 32)),
        ),
        title: const Text('Essential apps'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-app-button'),
        onPressed: _isLoading ? null : _openAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: <Widget>[
                  if (_warning != null)
                    StatusBanner(message: _warning!, icon: Icons.info_outline),
                  if (_error != null)
                    StatusBanner(
                      message: _error!,
                      icon: Icons.error_outline,
                      isError: true,
                    ),
                  Expanded(
                    child: _entries.isEmpty
                        ? EssentialAppsEmptyState(onAddPressed: _openAddSheet)
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: _entries.length,
                            onReorderItem: _reorderEntries,
                            itemBuilder: (BuildContext context, int index) {
                              final LauncherEntry entry = _entries[index];
                              return LauncherEntryTile(
                                key: ValueKey<String>(entry.id),
                                entry: entry,
                                index: index,
                                isFirst: index == 0,
                                isLast: index == _entries.length - 1,
                                onEdit: () => _openEntryForm(entry: entry),
                                onDelete: () => _deleteEntry(entry),
                                onMoveUp: () => _moveEntryUp(index),
                                onMoveDown: () => _moveEntryDown(index),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
