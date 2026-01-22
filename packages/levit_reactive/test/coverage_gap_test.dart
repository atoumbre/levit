import 'dart:async';

import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

// DefaultObserver extends LevitReactiveObserver which likely exists still?
// Wait, grep check pending.
// Assuming LevitReactiveObserver is separate interface for Proxy.
// But test group "LevitReactiveObserver default addReactive does nothing" implies it is testable.
// If it is internal abstract class, I can extend it.
class DefaultObserver extends LevitReactiveObserver {
  @override
  void addNotifier(LevitReactiveNotifier notifier) {}

  @override
  void addStream<T>(Stream<T> stream) {}
}

/// Test middleware to capture dependency graph changes
class DepGraphCapture extends LevitReactiveMiddleware {
  LxReactive? capturedComputed;
  List<LxReactive>? capturedDeps;

  @override
  void Function(LxReactive, List<LxReactive>)? get onGraphChange =>
      (computed, dependencies) {
        capturedComputed = computed;
        capturedDeps = dependencies;
      };
}

void main() {
  group('Coverage Gaps', () {
    test('LevitReactiveObserver default addReactive does nothing', () {
      // core.dart line 27
      final observer = DefaultObserver();
      final rx = LxVar(10);

      // Should not throw
      observer.addReactive(rx);
    });

    test('Sync Computed triggers onDependencyGraphChange via middleware', () {
      // computed.dart line 195
      final capture = DepGraphCapture();
      Lx.addMiddleware(capture);

      addTearDown(() => Lx.removeMiddleware(capture));

      final count = 0.lx;
      final doubleCount = (() => count.value * 2).lx;

      expect(doubleCount.value, 0);

      count.value++;

      expect(doubleCount.value, 2);
      expect(capture.capturedComputed, equals(doubleCount));
      expect(capture.capturedDeps, contains(count));
    });

    test('Pull-on-read Sync Computed triggers onDependencyGraphChange', () {
      // computed.dart lines 317-318
      final capture = DepGraphCapture();
      Lx.addMiddleware(capture);

      addTearDown(() => Lx.removeMiddleware(capture));

      final count = 10.lx;
      // create computed but don't listen to it -> Pull mode
      final computed = (() => count.value * 5).lx;

      // Read value directly
      final val = computed.value;

      expect(val, 50);
      // Middleware should have been called
      expect(capture.capturedComputed, equals(computed));
      expect(capture.capturedDeps, contains(count));
    });

    test('Async Computed triggers onDependencyGraphChange', () async {
      // computed.dart line 465
      final capture = DepGraphCapture();
      Lx.addMiddleware(capture);

      addTearDown(() => Lx.removeMiddleware(capture));

      final count = 20.lx;
      final completer = Completer<int>();

      final asyncComp = LxComputed.async(() async {
        final val = count.value; // Track dep
        return await completer.future + val;
      });

      // Use addListener to activate
      void listener() {}
      asyncComp.addListener(listener);

      expect(asyncComp.value, isA<LxWaiting>());

      completer.complete(5);
      await Future.delayed(Duration.zero);

      expect(asyncComp.value, isA<LxSuccess>());
      expect(asyncComp.value.valueOrNull, 25);

      expect(capture.capturedComputed, equals(asyncComp));
      expect(capture.capturedDeps, contains(count));

      asyncComp.removeListener(listener);
    });
  });
}
