import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_supply_flutter/main.dart';

void main() {
  testWidgets('Login screen displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MistyGoApp());

    expect(find.text('Misty Go Delivery'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
