import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nearfix/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('NearFixApp smoke test opens PhoneAuthScreen asking for mobile number first',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NearFixApp());
    await tester.pump();

    // Verify initial screen asks for mobile number first
    expect(find.text('NearSlay'), findsOneWidget);
    expect(find.text('Enter Mobile Number'), findsOneWidget);
    expect(find.text('Get OTP Verification Code'), findsOneWidget);
  });
}
