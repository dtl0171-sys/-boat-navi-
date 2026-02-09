import 'package:flutter_test/flutter_test.dart';
import 'package:boat_navi/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const BoatNaviApp());
    expect(find.text('Boat Navi'), findsOneWidget);
  });
}
