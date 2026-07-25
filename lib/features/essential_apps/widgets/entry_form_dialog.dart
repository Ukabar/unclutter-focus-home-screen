import 'package:flutter/material.dart';

import '../models/launcher_entry.dart';
import '../validation/launch_url_validator.dart';
import 'premium_components.dart';

class EntryFormDialog extends StatefulWidget {
  const EntryFormDialog({this.entry, super.key});

  final LauncherEntry? entry;

  @override
  State<EntryFormDialog> createState() => _EntryFormDialogState();
}

class _EntryFormDialogState extends State<EntryFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;

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
