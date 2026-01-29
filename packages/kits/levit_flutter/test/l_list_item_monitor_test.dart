import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  group('LListItemMonitor', () {
    testWidgets('triggers onInit when added to tree', (tester) async {
      var initCalled = false;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LWidgetMonitor(
            onInit: () => initCalled = true,
            child: const Text('Test'),
          ),
        ),
      );

      expect(initCalled, isTrue);
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('triggers onDispose when removed from tree', (tester) async {
      var disposeCalled = false;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LWidgetMonitor(
            onDispose: () => disposeCalled = true,
            child: const Text('Test'),
          ),
        ),
      );

      // Verify not called yet
      expect(disposeCalled, isFalse);

      // Remove widget
      await tester.pumpWidget(const SizedBox.shrink());

      expect(disposeCalled, isTrue);
    });

    testWidgets('renders child correctly', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: LWidgetMonitor(
            child: Text('Content'),
          ),
        ),
      );

      expect(find.text('Content'), findsOneWidget);
    });
  });
}
