import 'dart:mirrors';

import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class _MockMiddleware extends LevitReactiveMiddleware {
  bool removeListenerCalled = false;

  @override
  void Function(LxReactive, LxListenerContext?)? get stoppedListening =>
      (reactive, context) {
        removeListenerCalled = true;
      };
}

void main() {
  group('Computed Coverage', () {
    test('cleanupSubscriptions runs without middleware', () {
      final s = 0.lx;
      final c = (() => s.value * 2).lx;

      // Activate
      final sub = c.listen((_) {});

      // Update dependency
      s.value = 1;

      // Dispose computed (triggers cleanupSubscriptions)
      sub.close();

      // Assert no errors occurred during cleanup
      expect(c.hasListener, isFalse);
    });

    test('cleanupSubscriptions notifies middleware on removeListener', () {
      final middleware = _MockMiddleware();
      LevitReactiveMiddleware.add(middleware);
      addTearDown(() => LevitReactiveMiddleware.remove(middleware));

      final s = 0.lx;
      // Use a condition that starts true then becomes false to force unsubscribe
      final enable = true.lx;

      final c = (() {
        if (enable.value) {
          return s.value;
        }
        return -1;
      }).lx;

      // Activate to build graph: depends on [enable, s]
      final sub = c.listen((_) {});
      expect(c.value, 0);

      // Reset mock state from initialization
      middleware.removeListenerCalled = false;

      // Change condition to false.
      // This will trigger a recomputation.
      // In _reconcileDependencies (or _cleanupSubscriptions if we dispose),
      // it will realize 's' is no longer needed.
      enable.value = false;

      // 's' should be unsubscribed.
      // Verify middleware hook was called.
      expect(middleware.removeListenerCalled, isTrue);

      sub.close();
    });

    test('_unsubscribeFrom default branch recalculates graph depth', () {
      final source = 0.lx;
      final mid = (() => source.value + 1).lx;
      final computed = (() => mid.value + 1).lx;
      final sub = computed.listen((_) {});

      // Ensure dependency graph is initialized.
      expect(computed.value, 2);
      final beforeDepth = computed.graphDepth;

      final mirror = reflect(computed);
      final lib = mirror.type.owner as LibraryMirror;
      final symbol = MirrorSystem.getSymbol('_unsubscribeFrom', lib);

      // Invoke with default args so recalculateDepth=true branch executes.
      mirror.invoke(symbol, [mid]);

      expect(computed.graphDepth, lessThanOrEqualTo(beforeDepth));

      sub.close();
      computed.close();
      mid.close();
      source.close();
    });
  });
}
