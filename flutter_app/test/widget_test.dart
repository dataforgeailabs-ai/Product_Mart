import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_supply_flutter/main.dart';

void main() {
  testWidgets('Catalog opens on Products and switches to Food Items', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MistyGoApp());
    await tester.pump();

    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Food Items'), findsOneWidget);

    final tabBar = find.byType(TabBar);
    final controller = DefaultTabController.of(tester.element(tabBar));
    expect(controller.index, 0);

    await tester.tap(find.text('Food Items'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.index, 1);

    await tester.tap(find.text('Products'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.index, 0);
  });
}
