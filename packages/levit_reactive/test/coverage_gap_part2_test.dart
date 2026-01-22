import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

// Concrete Observer for testing
class GapTestObserver extends LevitReactiveMiddleware {
  int initCount = 0;
  @override
  void Function(LxReactive reactive)? get onInit => (reactive) => initCount++;
}

void main() {
  group('Coverage Gap Part 2', () {
    // Core.dart gaps
    test('Lx call() functor', () {
      final rx = LxInt(0);
      expect(rx(), 0);
      rx.value = 1; // Updated from rx(1) to be safe
      expect(rx.value, 1);
      expect(rx.call(), 1);

      final rx2 = 0.lx;
      expect(rx2(), 0);

      // LxComputed call() functor
      final dep = 0.lx;
      final computed = LxComputed(() => dep.value * 2);
      expect(computed(), 0);
    });

    // Removed LevitReactiveMiddleware default methods test as it tested deprecated API.

    // LxStream gap: ensure onInit called for observer
    test('LxStream constructor calls observer.onInit', () {
      final obs = GapTestObserver();
      Lx.addMiddleware(obs);
      addTearDown(() => Lx.removeMiddleware(obs));

      // Should define init count
      // LxStream itself -> init called (single identity)
      LxStream<int>.idle();
      expect(obs.initCount, 1);
    });

    // Computed.dart gaps
    // LxAsyncComputed is abstract, so we can't instantiate it directly.
    // However, we can create a subclass that uses the const constructor.
    test('LxAsyncComputed constructor', () {
      final computed = ConcreteAsyncComputed();
      expect(computed, isA<LxAsyncComputed>());
    });

    test('LxComputed batch update deferral', () {
      final dep = 0.lx;
      final computed = LxComputed(() => dep.value * 2);

      // Access value to make it clean (otherwise _onDependencyChanged won't trigger notify())
      expect(computed.value, 0);

      bool notified = false;
      computed.addListener(() => notified = true);

      // Act
      Lx.batch(() {
        dep.value = 1;
      });

      expect(notified, isTrue);
    });
  });
}

class ConcreteAsyncComputed extends LxAsyncComputed<int> {
  ConcreteAsyncComputed() : super(() async => 0);

  @override
  LxStatus<int> get value => LxSuccess(0); // Dummy

  @override
  Stream<LxStatus<int>> get stream => const Stream.empty();

  // Implementation details skipped
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
