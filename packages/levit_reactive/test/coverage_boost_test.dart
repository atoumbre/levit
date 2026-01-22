import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'dart:async';

class SimpleReactive<T> extends LxBase<T> {
  SimpleReactive(super.initial);
  set value(T v) => setValueInternal(v);
}

void main() {
  group('Levit Reactive Coverage Boost', () {
    test('_DependencyTracker Set mode (lines 535, 543-545)', () {
      final reactives = List.generate(10, (i) => SimpleReactive(i));

      final multiComputed = LxComputed(() {
        int sum = 0;
        for (var r in reactives) {
          sum += r.value;
        }
        return sum;
      });

      expect(multiComputed.value, 45);

      reactives[0].value = 10;
      expect(multiComputed.value, 55);
    });

    test('LevitReactiveHistoryMiddleware redoChanges integration', () {
      final history = LevitReactiveHistoryMiddleware();
      final rx = SimpleReactive(0);

      Lx.addMiddleware(history);
      addTearDown(() => Lx.clearMiddlewares());

      // Trigger change which goes through middleware
      rx.value = 1;

      expect(history.canUndo, true);
      expect(history.redoChanges.isEmpty, true);

      history.undo();
      expect(history.redoChanges.length, 1);
      expect(history.redoChanges.first.newValue, 1);
      expect(history.canUndo, false);
      expect(history.length, 0);
    });

    test('Extensions coverage (.lx)', () {
      final count = 0.lx;
      final doubled = (() => count.value * 2).lx;
      expect(doubled.value, 0);

      final asyncComp = (() async => 42).lx;
      expect(asyncComp, isA<LxAsyncComputed<int>>());
    });

    test('LxWatchStat copyWith isProcessing (line 59)', () {
      const stat = LxWatchStat();
      final stat2 = stat.copyWith(isProcessing: true, isAsync: true);
      expect(stat2.isProcessing, true);
      expect(stat2.isAsync, true);
    });

    test('LxWatch detected async coverage extra', () async {
      final rx = SimpleReactive(0);
      final watch = LxWatch(rx, (val) async {
        await Future.delayed(Duration(milliseconds: 10));
      });

      rx.value = 1;
      await Future.delayed(Duration(milliseconds: 50));
      expect(watch.value.isProcessing, false);
    });

    test('Listener modification during notification (core.dart lines 312, 325)',
        () {
      final rx = SimpleReactive(0);

      void listener1() {
        // Add another listener during notification
        rx.addListener(() {});
        // Remove another listener during notification
        // (we need a reference to something else to remove)
      }

      void listenerToRemove() {}
      rx.addListener(listenerToRemove);

      void listener2() {
        rx.removeListener(listenerToRemove);
      }

      rx.addListener(listener1);
      rx.addListener(listener2);

      // Trigger notifications to hit _notificationDepth > 0 blocks
      rx.value = 1;
    });

    test('_cleanupSubscriptions coverage (computed.dart line 424)', () {
      final rx = 0.lx;
      final comp = LxComputed(() => rx.value);

      // Activate
      final sub = comp.stream.listen((_) {});

      // Inactivate (triggers _onInactive -> _cleanupSubscriptions)
      sub.cancel();
    });
  });
}
