import 'package:test/test.dart';
import 'package:levit_dart/levit_dart.dart';

class TestController extends LevitController {
  final count = 0.lx;
  final text = ''.lx;

  late final flow = 0.lx;

  @override
  void onInit() {
    super.onInit();
    flow.value = 1;
  }
}

class AsyncTestController extends LevitController {
  final count = 0.lx;
}

void main() {
  setUp(() {
    Levit.reset(force: true);
    Levit.enableAutoLinking();
  });

  group('AutoDispose', () {
    test('captures reactive variables in constructor via put', () {
      final controller = Levit.put(() => TestController());

      expect(controller.count.ownerId, isNotNull);
      expect(controller.count.ownerId, contains('TestController'));
      expect(controller.text.ownerId, isNotNull);

      // Verify disposal
      expect(controller.count.isDisposed, isFalse);
      Levit.delete<TestController>();
      expect(controller.count.isDisposed, isTrue);
      expect(controller.text.isDisposed, isTrue);
    });

    test('captures reactive variables in onInit via put', () {
      final controller = Levit.put(() => TestController());

      expect(controller.flow.ownerId, isNotNull);
      expect(controller.flow.ownerId, contains('TestController'));

      Levit.delete<TestController>();
      expect(controller.flow.isDisposed, isTrue);
    });

    test('captures reactive variables via lazyPut', () {
      Levit.lazyPut(() => TestController());
      final controller = Levit.find<TestController>();

      expect(controller.count.ownerId, isNotNull);
      expect(controller.flow.ownerId, isNotNull);

      expect(controller.count.isDisposed, isFalse);
      Levit.delete<TestController>();
      expect(controller.count.isDisposed, isTrue);
      expect(controller.flow.isDisposed, isTrue);
    });

    test('captures reactive variables via lazyPutAsync', () async {
      Levit.lazyPutAsync(() async {
        await Future.delayed(Duration(milliseconds: 10));
        return AsyncTestController();
      });

      final controller = await Levit.findAsync<AsyncTestController>();

      // For lazyPutAsync, LevitScope uses `findAsync`.
      // LevitScope.findAsync calls `builder` (wrapped by hooks).
      // So Observer onCreate IS called for the async builder.
      // Observer onCreate returns async wrapper.
      // Async wrapper captures and registers.

      expect(controller.count.ownerId, isNotNull);
      expect(controller.count.isDisposed, isFalse);

      Levit.delete<AsyncTestController>();
      expect(controller.count.isDisposed, isTrue);
    });
  });
}
