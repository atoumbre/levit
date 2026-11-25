import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

import '../helpers.dart';

void main() {
  setUp(() async {
    await Levit.reset(force: true);
  });

  group('LevitController (Flutter Extensions)', () {
    test('disposes owned ChangeNotifier on close', () async {
      final controller = TestController();
      final notifier = TestNotifier();

      // Use Flutter extension for ChangeNotifier
      controller.own(notifier, dispose: (value) => value.dispose());
      controller.own(() => null);

      await controller.onClose();

      expect(notifier.isDisposed, isTrue);
    });
  });
}
