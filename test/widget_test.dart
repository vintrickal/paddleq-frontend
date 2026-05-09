import 'package:flutter_test/flutter_test.dart';
import 'package:paddleq/app.dart';

void main() {
  testWidgets('PaddleQ app renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PaddleQApp());
    expect(find.text('PaddleQ'), findsWidgets);
  });
}
