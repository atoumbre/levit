import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class TestBatchFilterMiddleware extends LevitReactiveMiddleware {
  final bool shouldProcessBatchFlag;
  final void Function(LevitReactiveBatch)? onBefore;
  final void Function(LevitReactiveBatch)? onAfter;

  TestBatchFilterMiddleware({
    this.shouldProcessBatchFlag = true,
    this.onBefore,
    this.onAfter,
  });

  @override
  LxOnBatch? get onBatch => (next, change) {
        if (!shouldProcessBatchFlag) {
          return next;
        }

        return () {
          onBefore?.call(change);
          try {
            return next();
          } finally {
            onAfter?.call(change);
          }
        };
      };
}

void main() {
  group('Middleware Batch Processing', () {
    setUp(() {
      Lx.clearMiddlewares();
    });

    tearDown(() {
      Lx.clearMiddlewares();
    });

    test('shouldProcessBatch=true allows batch hooks', () {
      bool beforeCalled = false;
      bool afterCalled = false;

      Lx.addMiddleware(TestBatchFilterMiddleware(
        shouldProcessBatchFlag: true,
        onBefore: (_) => beforeCalled = true,
        onAfter: (_) => afterCalled = true,
      ));

      Lx.batch(() {
        final i = LxInt(0);
        i.value = 1;
      });

      expect(beforeCalled, isTrue);
      expect(afterCalled, isTrue);
    });

    test('shouldProcessBatch=false prevents batch hooks', () {
      bool beforeCalled = false;
      bool afterCalled = false;

      Lx.addMiddleware(TestBatchFilterMiddleware(
        shouldProcessBatchFlag: false,
        onBefore: (_) => beforeCalled = true,
        onAfter: (_) => afterCalled = true,
      ));

      Lx.batch(() {
        final i = LxInt(0);
        i.value = 1;
      });

      expect(beforeCalled, isFalse);
      expect(afterCalled, isFalse);
    });

    test('multiple middlewares respect their own shouldProcessBatch', () {
      bool mw1Called = false;
      bool mw2Called = false;

      // MW1: Allows batch
      Lx.addMiddleware(TestBatchFilterMiddleware(
        shouldProcessBatchFlag: true,
        onAfter: (_) => mw1Called = true,
      ));

      // MW2: Denies batch
      Lx.addMiddleware(TestBatchFilterMiddleware(
        shouldProcessBatchFlag: false,
        onAfter: (_) => mw2Called = true,
      ));

      Lx.batch(() {
        final i = LxInt(0);
        i.value = 1;
      });

      expect(mw1Called, isTrue);
      expect(mw2Called, isFalse);
    });
  });
}
