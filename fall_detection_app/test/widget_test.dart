import 'package:flutter_test/flutter_test.dart';
import 'package:fall_detection_app/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FallDetectionApp());
    expect(find.byType(FallDetectionApp), findsOneWidget);
  });
}
