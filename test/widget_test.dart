import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quickserve/main.dart';
import 'package:quickserve/services/app_state.dart';

void main() {
  testWidgets('app loads the auth screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.initialize();

    await tester.pumpWidget(QuickServeApp(state: state));

    expect(find.text('Welcome to QuickServe.'), findsOneWidget);
  });
}
