import 'package:flutter/material.dart';

import '../catalog/catalog_app.dart';
import '../models/launcher_entry.dart';
import '../validation/launch_url_validator.dart';

class CatalogPickerSheet extends StatefulWidget {
  const CatalogPickerSheet({
    required this.apps,
    required this.selectedEntries,
    required this.onManualEntry,
    super.key,
  });

  final List<CatalogApp> apps;
  final List<LauncherEntry> selectedEntries;
  final VoidCallback onManualEntry;

  @override
  State<CatalogPickerSheet> createState() => _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends State<CatalogPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Set<String> selectedUrls = widget.selectedEntries.map((
      LauncherEntry entry,
    ) {
      return LaunchUrlValidator.duplicateKey(entry.launchUrl);
    }).toSet();
    final List<CatalogApp> filteredApps = widget.apps.where((CatalogApp app) {
      return app.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Add app',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('catalog-search-field'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Search catalog',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (String value) {
                  setState(() {
                    _query = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('manual-entry-button'),
                onPressed: widget.onManualEntry,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Add manually'),
              ),
              const Divider(),
              Expanded(
                child: filteredApps.isEmpty
                    ? const Center(child: Text('No catalog apps found.'))
                    : ListView.builder(
                        itemCount: filteredApps.length,
                        itemBuilder: (BuildContext context, int index) {
                          final CatalogApp app = filteredApps[index];
                          final bool isSelected = selectedUrls.contains(
                            LaunchUrlValidator.duplicateKey(app.launchUrl),
                          );

                          return ListTile(
                            enabled: !isSelected,
                            title: Text(app.name),
                            subtitle: Text(app.category ?? app.launchUrl),
                            trailing: isSelected
                                ? const Icon(Icons.check)
                                : const Icon(Icons.add),
                            onTap: isSelected
                                ? null
                                : () => Navigator.of(context).pop(app),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
