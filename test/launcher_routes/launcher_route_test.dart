import 'package:stillscreen_focus_launcher/features/launcher_routes/launcher_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates internal launcher and setup routes', () {
    expect(
      LauncherRoute.launchUri('entry-123').toString(),
      'focuslauncher://launch?id=entry-123',
    );
    expect(LauncherRoute.setupUri().toString(), 'focuslauncher://setup');
  });

  test('parses valid launcher route', () {
    final LauncherRouteParseResult result = LauncherRoute.parse(
      'focuslauncher://launch?id=entry-123',
    );

    expect(result.status, LauncherRouteParseStatus.valid);
    expect(result.route!.kind, LauncherRouteKind.launch);
    expect(result.route!.entryId, 'entry-123');
  });

  test('rejects missing and invalid ids', () {
    expect(
      LauncherRoute.parse('focuslauncher://launch').status,
      LauncherRouteParseStatus.missingId,
    );
    expect(
      LauncherRoute.parse('focuslauncher://launch?id=bad%20id').status,
      LauncherRouteParseStatus.invalidId,
    );
    expect(() => LauncherRoute.launchUri('bad id'), throwsArgumentError);
  });

  test('rejects unrelated routes', () {
    expect(
      LauncherRoute.parse('https://example.com/launch?id=entry-123').status,
      LauncherRouteParseStatus.invalid,
    );
  });
}
