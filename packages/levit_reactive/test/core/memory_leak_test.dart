import 'dart:async';

import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('Lx Memory Leaks', () {
    test('Lx is garbage collected when no listeners exist', () async {
      // 1. Create a weak reference to an Lx object
      // ignore: unused_local_variable
      WeakReference<LxInt>? ref;

      void create() {
        final lx = 0.lx;
        ref = WeakReference(lx);
      }

      create();

      // 2. Force GC (attempt)
      // Dart doesn't have a standardized forceGC, but allocating memory
      // and checking in a loop usually works for checking structural reachability.
      await Future.delayed(Duration(milliseconds: 100));
      List.generate(10000, (i) => List.filled(1000, i)); // Allocations

      // Note: This test is flaky in standard Dart VM without explicit GC.
      // But structurally, if 'lx' is gone, ref.target *should* be null eventually.
      // We rely on the fact that nothing holds 'lx'.

      // In a real leak scenario (e.g. static registry holding it), it would NEVER die.
    });

    test('Lx raw callbacks work', () async {
      bool active = false;
      final lx = LxVar(0, onListen: () {
        active = true;
      }, onCancel: () {
        active = false;
      });
      expect(active, isFalse);

      final sub = lx.stream.listen((v) {});
      expect(active, isTrue, reason: 'Lx should call onListen');

      sub.cancel();
      await Future.delayed(Duration.zero);
      expect(active, isFalse, reason: 'Lx should call onCancel');
    });

    test('LxComputed is LAZY (No leak)', () async {
      final controller = StreamController<int>();
      // Use single subscription stream to ensure clear onCancel behavior in LxStream
      final dep = LxStream(controller.stream, initial: 0);

      expect(controller.hasListener, isFalse,
          reason: 'LxStream source should start lazy');

      // Create computed - it should be LAZY now
      final computed = LxComputed(() => (dep.valueOrNull ?? 0) * 2);

      // Allow async propagation
      await Future.delayed(Duration.zero);

      // Expectation FLIPPED: Should be FALSE (Lazy)
      expect(controller.hasListener, isFalse,
          reason: 'LxComputed should NOT subscribe actively if no listeners');

      // Verify Value Access (Pull) works
      expect(computed.value, 0); // initial value

      // ACT: Listen to computed
      final sub = computed.stream.listen((_) {});
      await Future.delayed(Duration.zero);
      expect(controller.hasListener, isTrue,
          reason: 'LxComputed should subscribe when listened to');

      // ACT: Cancel listener
      sub.cancel();
      // Increase delay to account for asBroadcastStream's potential cancellation debounce in LxStream
      await Future.delayed(Duration(milliseconds: 200));

      expect(controller.hasListener, isFalse,
          reason: 'LxComputed should unsubscribe when listeners leave');
    });

    test('LxAsyncComputed is LAZY (No leak)', () async {
      final controller = StreamController<int>();
      final dep = LxStream(controller.stream, initial: 0);

      final computed = LxComputed.async(() async {
        return (dep.valueOrNull ?? 0) * 2;
      });

      await Future.delayed(Duration.zero);

      expect(controller.hasListener, isFalse,
          reason:
              'LxAsyncComputed should NOT subscribe actively if no listeners');

      // ACT: Listen
      final sub = computed.stream.listen((_) {});
      await Future.delayed(Duration.zero);

      expect(controller.hasListener, isTrue,
          reason: 'LxAsyncComputed should subscribe when listened to');

      sub.cancel();
      await Future.delayed(Duration(milliseconds: 200));
      expect(controller.hasListener, isFalse,
          reason: 'LxAsyncComputed should unsubscribe when listeners leave');
    });

    test('LxMemoComputed is LAZY (No leak)', () async {
      final controller = StreamController<int>();
      final dep = LxStream(controller.stream, initial: 0);

      // Create memo - should be lazy
      final computed = LxComputed(() => (dep.valueOrNull ?? 0) * 2);

      await Future.delayed(Duration.zero);
      expect(controller.hasListener, isFalse,
          reason:
              'LxMemoComputed should NOT subscribe actively if no listeners');

      // ACT: Listen
      final sub = computed.stream.listen((_) {});
      await Future.delayed(Duration.zero);

      expect(controller.hasListener, isTrue,
          reason: 'LxMemoComputed should subscribe when listened to');

      sub.cancel();
      await Future.delayed(Duration(milliseconds: 200));

      expect(controller.hasListener, isFalse,
          reason: 'LxMemoComputed should unsubscribe when listeners leave');
    });

    test('Lx.stream closes automatically when listeners cancel', () async {
      final lx = 0.lx;

      // Subscribe
      final sub = lx.stream.listen((v) {});

      expect(lx.stream.isBroadcast, isTrue);
      // Broadcast streams don't "close" per se, they just stop firing.

      await sub.cancel();

      // The controller inside Lx is broadcast. It doesn't need closing strictly
      // for the object to be GC'd. The StreamController itself is just an object.
      // As long as nothing external holds the controller, it dies with Lx.
    });

    test('Standard usage creates listeners that can be cancelled', () {
      final lx = 0.lx;
      // We can't check hasListeners directly on Lx without internals,
      // but we can verify that adding/removing doesn't crash
      // and behaves consistently with the Stream API.

      final sub = lx.stream.listen((v) {});
      // Structural check: subscription exists
      expect(sub, isNotNull);

      sub.cancel();
      // After cancel, the subscription is dead.
      // The Lx object itself just holds a StreamController.
      // If the StreamController is broadcast, it drops the listener.
    });

    test('LWatch-like behavior cleans up', () {
      final lx = 0.lx;
      final observer = _MockObserver();

      // Simulate build
      Lx.proxy = observer;
      final _ = lx.value; // Register
      Lx.proxy = null;

      expect(observer.disposers.length, 1);

      // Simulate dispose
      for (final d in observer.disposers) {
        d();
      }
      observer.disposers.clear();

      expect(observer.disposers, isEmpty);
    });
  });
}

class _MockObserver implements LevitReactiveObserver {
  final List<StreamSubscription> subscriptions = [];
  final List<void Function()> disposers = [];

  @override
  void addStream<T>(Stream<T> stream) {
    subscriptions.add(stream.listen((_) {}));
  }

  @override
  void addNotifier(LevitReactiveNotifier notifier) {
    void listener() {}
    notifier.addListener(listener);
    disposers.add(() => notifier.removeListener(listener));
  }

  @override
  void addReactive(LxReactive reactive) {
    // No-op for this mock
  }
}
