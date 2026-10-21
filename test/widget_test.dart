import 'package:flutter_test/flutter_test.dart';
import 'package:carrom_aim_bot/main.dart';

void main() {
  testWidgets('CarromAimBotApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CarromAimBotApp());
    expect(find.text('Carrom Aim Assistant'), findsOneWidget);
  });
}
