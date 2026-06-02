import 'package:flutter_test/flutter_test.dart';
import 'package:sweeda_real_estate/app.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const SweedaRealEstateApp());
    expect(find.text('عقارات السويداء'), findsOneWidget);
  });
}