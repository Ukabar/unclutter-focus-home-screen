class LaunchUrlValidator {
  static const Set<String> _blockedSchemes = <String>{
    'about',
    'data',
    'file',
    'javascript',
    'vbscript',
  };

  static final RegExp _schemePattern = RegExp(r'^[a-z][a-z0-9+.-]*$');
  static final RegExp _whitespacePattern = RegExp(r'\s');

  static String normalize(String value) => value.trim();

  static String? validate(String value) {
    final String normalized = normalize(value);

    if (normalized.isEmpty) {
      return 'Enter a URL or URL scheme.';
    }

    if (_whitespacePattern.hasMatch(normalized)) {
      return 'URLs cannot contain spaces.';
    }

    final Uri? uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme) {
      return 'Enter a valid URL with a scheme, such as maps: or https://example.com.';
    }

    final String scheme = uri.scheme.toLowerCase();
    if (!_schemePattern.hasMatch(scheme)) {
      return 'The URL scheme is malformed.';
    }

    if (_blockedSchemes.contains(scheme)) {
      return 'That URL scheme is not supported.';
    }

    if ((scheme == 'http' || scheme == 'https') && (uri.host.isEmpty)) {
      return 'Web URLs must include a host.';
    }

    return null;
  }

  static String duplicateKey(String value) {
    final Uri uri = Uri.parse(normalize(value));
    return uri.toString().toLowerCase();
  }
}
