import 'package:flutter/material.dart';

import '../../launcher_routes/launcher_target_opener.dart';
import '../models/launcher_entry.dart';
import '../validation/launch_url_validator.dart';
import 'premium_components.dart';

class EntryFormDialog extends StatefulWidget {
  const EntryFormDialog({
    this.entry,
    this.targetOpener = const UrlLauncherTargetOpener(),
    super.key,
  });

  final LauncherEntry? entry;
  final LauncherTargetOpener targetOpener;

  @override
  State<EntryFormDialog> createState() => _EntryFormDialogState();
}

class _EntryFormDialogState extends State<EntryFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  bool _isTestingLaunch = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry?.name);
    _urlController = TextEditingController(text: widget.entry?.launchUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final LauncherEntry nextEntry = widget.entry == null
        ? LauncherEntry.fromUserInput(
            name: _nameController.text,
            launchUrl: _urlController.text,
          )
        : widget.entry!.copyWith(
            name: _nameController.text.trim(),
            launchUrl: LaunchUrlValidator.normalize(_urlController.text),
          );

    Navigator.of(context).pop(nextEntry);
  }

  Future<void> _testLaunch() async {
    final String? validationError = LaunchUrlValidator.validate(
      _urlController.text,
    );
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    setState(() => _isTestingLaunch = true);
    final bool opened = await widget.targetOpener.open(_urlController.text);
    if (!mounted) {
      return;
    }
    setState(() => _isTestingLaunch = false);
    _showMessage(
      opened
          ? 'Launch test sent. Return here to save it.'
          : 'This link could not be opened. Check that the app is installed and supports this URL.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: PremiumCard(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                PremiumSectionHeader(
                  title: _isEditing ? 'Edit app' : 'Manual app',
                  subtitle: 'Add a trusted URL scheme or universal link.',
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const Key('entry-name-field'),
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a display name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('entry-url-field'),
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL or scheme',
                    helperText:
                        'Valid formatting does not guarantee that an app supports the link.',
                  ),
                  validator: (String? value) {
                    return LaunchUrlValidator.validate(value ?? '');
                  },
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton.icon(
                      key: const Key('entry-test-launch-button'),
                      onPressed: _isTestingLaunch ? null : _testLaunch,
                      icon: _isTestingLaunch
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.open_in_new),
                      label: const Text('Test'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      key: const Key('entry-submit-button'),
                      onPressed: _submit,
                      child: Text(_isEditing ? 'Save' : 'Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
