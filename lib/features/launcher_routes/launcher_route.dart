class LauncherRoute {
  const LauncherRoute._({required this.kind, this.entryId});

  static const String scheme = 'dumbphonehomescreen';
  static const String launchHost = 'launch';
  static const String setupHost = 'setup';

  static final RegExp _entryIdPattern = RegExp(r'^[A-Za-z0-9._-]{1,128}$');

  final LauncherRouteKind kind;
  final String? entryId;

  static Uri launchUri(String entryId) {
    if (!isValidEntryId(entryId)) {
      throw ArgumentError.value(
        entryId,
        'entryId',
        'Invalid launcher entry id.',
      );
    }

    return Uri(
      scheme: scheme,
      host: launchHost,
      queryParameters: <String, String>{'id': entryId},
    );
  }

  static Uri setupUri() => Uri(scheme: scheme, host: setupHost);

  static LauncherRouteParseResult parse(String rawRoute) {
    final Uri? uri = Uri.tryParse(rawRoute.trim());
    if (uri == null || uri.scheme.toLowerCase() != scheme) {
      return const LauncherRouteParseResult.invalid();
    }

    final String host = uri.host.toLowerCase();
    if (host == setupHost) {
      return const LauncherRouteParseResult.valid(
        LauncherRoute._(kind: LauncherRouteKind.setup),
      );
    }

    if (host != launchHost) {
      return const LauncherRouteParseResult.invalid();
    }

    final String? entryId = uri.queryParameters['id'];
    if (entryId == null || entryId.isEmpty) {
      return const LauncherRouteParseResult.missingId();
    }

    if (!isValidEntryId(entryId)) {
      return const LauncherRouteParseResult.invalidId();
    }

    return LauncherRouteParseResult.valid(
      LauncherRoute._(kind: LauncherRouteKind.launch, entryId: entryId),
    );
  }

  static bool isValidEntryId(String value) {
    return _entryIdPattern.hasMatch(value.trim());
  }
}

enum LauncherRouteKind { launch, setup }

class LauncherRouteParseResult {
  const LauncherRouteParseResult._({required this.status, this.route});

  const LauncherRouteParseResult.valid(LauncherRoute route)
    : this._(status: LauncherRouteParseStatus.valid, route: route);

  const LauncherRouteParseResult.invalid()
    : this._(status: LauncherRouteParseStatus.invalid);

  const LauncherRouteParseResult.missingId()
    : this._(status: LauncherRouteParseStatus.missingId);

  const LauncherRouteParseResult.invalidId()
    : this._(status: LauncherRouteParseStatus.invalidId);

  final LauncherRouteParseStatus status;
  final LauncherRoute? route;
}

enum LauncherRouteParseStatus { valid, invalid, missingId, invalidId }
