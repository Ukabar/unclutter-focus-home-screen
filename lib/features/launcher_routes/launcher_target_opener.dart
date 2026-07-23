import 'package:url_launcher/url_launcher.dart';

import '../essential_apps/validation/launch_url_validator.dart';

abstract interface class LauncherTargetOpener {
  Future<bool> open(String launchUrl);
}

class UrlLauncherTargetOpener implements LauncherTargetOpener {
  const UrlLauncherTargetOpener();

  @override
  Future<bool> open(String launchUrl) async {
    if (LaunchUrlValidator.validate(launchUrl) != null) {
      return false;
    }

    final Uri? uri = Uri.tryParse(LaunchUrlValidator.normalize(launchUrl));
    if (uri == null) {
      return false;
    }

    try {
      return await launchUrlWithMode(uri);
    } on Object {
      return false;
    }
  }

  Future<bool> launchUrlWithMode(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
