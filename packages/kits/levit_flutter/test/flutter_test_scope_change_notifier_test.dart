import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_testing.dart';

class _SpyChangeNotifier extends ChangeNotifier {
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _SearchController extends LevitController {
  late final queryController = own(TextEditingController(text: 'levit'));
  late final spy = own(_SpyChangeNotifier());
}

void main() {
  test(
    'LevitTestScope from levit_flutter initializes ChangeNotifier disposal automatically',
    () async {
      final harness = LevitTestScope();
      final controller = harness.run(
        () => harness.scope.put(_SearchController.new),
      );

      expect(controller.queryController.text, 'levit');
      expect(controller.spy.disposed, isFalse);

      await harness.close();

      expect(controller.spy.disposed, isTrue);
      expect(
        () => controller.queryController.addListener(() {}),
        throwsFlutterError,
      );
    },
  );
}
