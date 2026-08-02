import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stillscreen_focus_launcher/app/app.dart';

void main() {
  testWidgets('Stillscreen app builds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const StillscreenFocusLauncherApp(showOnboarding: false),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
