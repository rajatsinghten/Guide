import 'package:flutter_test/flutter_test.dart';
import 'package:gigshield_verify/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const GigShieldVerifyApp());
  });
}
