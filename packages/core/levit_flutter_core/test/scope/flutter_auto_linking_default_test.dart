import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_dart_core/spi.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class _AutoLinkedController extends LevitController {
  final count = 0.lx;
}

void main() {
  tearDown(() {
    Levit.disableAutoLinking();
    LevitAutoLinkSpi.resetAutoLinkingPreference();
  });

  group('Flutter default auto-linking', () {
    testWidgets('LScope enables auto-linking automatically on first mount', (
      tester,
    ) async {
      Levit.disableAutoLinking();
      LevitAutoLinkSpi.resetAutoLinkingPreference();
      expect(Levit.isAutoLinkingEnabled, isFalse);

      late _AutoLinkedController controller;
      final lifecycle = LevitScopeLifecycleController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            lifecycle: lifecycle,
            configure: (scope) {
              controller = scope.put(() => _AutoLinkedController());
            },
            child: const SizedBox.shrink(),
          ),
        ),
      );

      expect(Levit.isAutoLinkingEnabled, isTrue);
      expect(controller.count.isDisposed, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await lifecycle.close();

      expect(controller.count.isDisposed, isTrue);
    });

    testWidgets(
      'LAsyncScope enables auto-linking automatically on first mount',
      (tester) async {
        Levit.disableAutoLinking();
        LevitAutoLinkSpi.resetAutoLinkingPreference();
        expect(Levit.isAutoLinkingEnabled, isFalse);

        late _AutoLinkedController controller;
        final lifecycle = LevitScopeLifecycleController();

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: LAsyncScope(
              lifecycle: lifecycle,
              configure: (scope) async {
                controller = scope.put(() => _AutoLinkedController());
              },
              child: const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pump();

        expect(Levit.isAutoLinkingEnabled, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        await lifecycle.close();

        expect(controller.count.isDisposed, isTrue);
      },
    );

    testWidgets('respects explicit disableAutoLinking opt-out', (tester) async {
      Levit.disableAutoLinking();
      expect(Levit.isAutoLinkingEnabled, isFalse);

      late _AutoLinkedController controller;
      final lifecycle = LevitScopeLifecycleController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            lifecycle: lifecycle,
            configure: (scope) {
              controller = scope.put(() => _AutoLinkedController());
            },
            child: const SizedBox.shrink(),
          ),
        ),
      );

      expect(Levit.isAutoLinkingEnabled, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await lifecycle.close();

      expect(controller.count.isDisposed, isFalse);
      await controller.count.close();
    });
  });
}
