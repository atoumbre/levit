import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

import '../helpers.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('LevitController (Flutter Extensions)', () {
    test('disposes ChangeNotifier on close via autoDisposeNotifier', () {
      final controller = TestController();
      final notifier = TestNotifier();

      // Use Flutter extension for ChangeNotifier
      controller.autoDispose(notifier);
      controller.autoDispose(() => null);

      controller.onClose();

      expect(notifier.isDisposed, isTrue);
    });
  });
}
