import 'package:flutter_test/flutter_test.dart';
import 'package:aenzbi_invoice/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AenzbiInvoiceApp());
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
