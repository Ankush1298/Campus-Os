import 'package:flutter_test/flutter_test.dart';
import 'package:campus_os/app/campus_app.dart';

void main() {
  testWidgets('CampusOS app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusApp());
    expect(find.text('CampusOS'), findsOneWidget);
    expect(find.text('Sign In to Your Campus Portal'), findsOneWidget);
  });
}
