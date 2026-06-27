import 'package:flutter_test/flutter_test.dart';
import 'package:doctor/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ClinicApp(isLoggedIn: false));
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}
