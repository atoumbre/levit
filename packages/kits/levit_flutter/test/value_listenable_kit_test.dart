import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../example/lib/countdown_interop.dart';

void main() {
  testWidgets(
    'kit exports the adapter and feature teardown closes the countdown example',
    (tester) async {
      Levit.enableAutoLinking();
      addTearDown(Levit.disableAutoLinking);
      await tester.pumpWidget(const CountdownInteropApp());
      final context = tester.element(
        find.byType(ValueListenableBuilder<Duration>),
      );
      final controller = context.levit.find<CountdownInteropController>();
      final display = controller.display as LevitValueListenable<Duration>;
      expect(find.text('5.0 s'), findsOneWidget);
      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(controller.countdown.isPaused, isTrue);
      await tester.tap(find.text('Resume'));
      expect(controller.countdown.isRunning, isTrue);
      await tester.tap(find.text('Stop'));
      await tester.pump();
      expect(controller.countdown.remaining.value, const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.disposed;
      expect(display.isDisposed, isTrue);
      expect(controller.countdown.isDisposed, isTrue);
      expect(controller.countdown.remaining.isDisposed, isTrue);
    },
  );
}
