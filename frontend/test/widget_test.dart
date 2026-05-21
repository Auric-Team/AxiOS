import 'package:flutter_test/flutter_test.dart';
import 'package:installer/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AxiOSInstallerApp());
    expect(find.byType(AxiOSInstallerApp), findsOneWidget);
  });
}
