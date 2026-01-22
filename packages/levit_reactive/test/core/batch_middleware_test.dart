import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('Batch async with middleware', () {
    test('awaits middleware-wrapped batch execution', () async {
      final middleware = TestBatchMiddleware();
      Lx.addMiddleware(middleware);

      final source = 0.lx;
      var middlewareCalled = false;

      middleware.onBatchCallback = (next, change) {
        middlewareCalled = true;
        return () async {
          final result = next();
          if (result is Future) {
            return await result;
          }
          return result;
        };
      };

      await Lx.batchAsync(() async {
        source.value = 10;
        await Future.delayed(Duration(milliseconds: 10));
        source.value = 20;
      });

      expect(middlewareCalled, true);
      expect(source.value, 20);

      Lx.removeMiddleware(middleware);
      source.close();
    });

    test('middleware can transform batch result', () async {
      final middleware = TestBatchMiddleware();
      Lx.addMiddleware(middleware);

      var transformCalled = false;

      middleware.onBatchCallback = (next, change) {
        return () async {
          transformCalled = true;
          final result = next();
          if (result is Future) {
            return await result;
          }
          return result;
        };
      };

      final result = await Lx.batchAsync(() async {
        await Future.delayed(Duration(milliseconds: 10));
        return 42;
      });

      expect(transformCalled, true);
      expect(result, 42);

      Lx.removeMiddleware(middleware);
    });
  });
}

class TestBatchMiddleware extends LevitReactiveMiddleware {
  Function? onBatchCallback;

  @override
  LxOnBatch? get onBatch => (next, change) {
        if (onBatchCallback != null) {
          return onBatchCallback!(next, change);
        }
        return next;
      };
}
