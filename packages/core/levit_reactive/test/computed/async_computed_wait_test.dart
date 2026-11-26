import 'dart:async';

import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LxAsyncComputed.wait', () {
    test('activates inactive computed and resolves once settled', () async {
      final source = 2.lx;
      final computed = LxComputed.async(() async {
        final v = source.value;
        await Future<void>.delayed(Duration.zero);
        return v * 10;
      });

      expect(computed.hasListener, isFalse);
      final result = await computed.wait;
      expect(result, 20);
      expect(computed.hasListener, isFalse);

      await computed.close();
      await source.close();
    });

    test('returns current settled value immediately while active', () async {
      final source = 1.lx;
      var runs = 0;
      final computed = LxComputed.async(() async {
        runs++;
        final v = source.value;
        await Future<void>.delayed(Duration.zero);
        return 'v$v';
      });

      void listener() {}
      computed.addListener(listener);

      expect(await computed.wait, 'v1');
      expect(await computed.wait, 'v1');
      expect(runs, 1);

      source.value = 2;
      expect(await computed.wait, 'v2');
      expect(runs, 2);

      computed.removeListener(listener);
      await computed.close();
      await source.close();
    });

    test('resolves to latest result across rapid invalidations', () async {
      final source = 0.lx;
      final gates = <int, Completer<String>>{};
      final computed = LxComputed.async(() {
        final v = source.value;
        return (gates[v] ??= Completer<String>()).future;
      });

      void listener() {}
      computed.addListener(listener);

      final pending = computed.wait;
      source.value = 1;
      source.value = 2;

      gates[0]!.complete('stale-0');
      gates[1]!.complete('stale-1');
      gates[2]!.complete('fresh-2');

      expect(await pending, 'fresh-2');

      computed.removeListener(listener);
      await computed.close();
      await source.close();
    });

    test(
      'waits for trailing exhaustLatest execution before settling',
      () async {
        final source = 0.lx;
        final firstGate = Completer<String>();
        final trailingGate = Completer<String>();
        var calls = 0;

        final computed = LxComputed.async(() {
          source.value;
          calls++;
          return calls == 1 ? firstGate.future : trailingGate.future;
        }, concurrency: LxAsyncConcurrency.exhaustLatest);

        void listener() {}
        computed.addListener(listener);

        final pending = computed.wait;
        source.value = 1;
        firstGate.complete('first');
        await Future<void>.delayed(Duration.zero);
        trailingGate.complete('trailing');

        expect(await pending, 'trailing');
        expect(calls, 2);

        computed.removeListener(listener);
        await computed.close();
        await source.close();
      },
    );

    test('propagates synchronous and asynchronous errors', () async {
      final mode = 0.lx;
      final computed = LxComputed.async<int>(() {
        if (mode.value == 0) throw StateError('sync boom');
        return Future<int>.error(ArgumentError('async boom'));
      });

      void listener() {}
      computed.addListener(listener);

      await expectLater(computed.wait, throwsA(isA<StateError>()));
      // Settled error is re-surfaced on subsequent wait calls.
      await expectLater(computed.wait, throwsA(isA<StateError>()));

      mode.value = 1;
      await expectLater(computed.wait, throwsA(isA<ArgumentError>()));

      computed.removeListener(listener);
      await computed.close();
      await mode.close();
    });

    test(
      'fails pending waiters with LxCancelledException on close or deactivation',
      () async {
        final gate = Completer<int>();
        final computed = LxComputed.async(() => gate.future);

        void listener() {}
        computed.addListener(listener);

        final deactivatedWait = computed.wait;
        computed.removeListener(listener);
        await expectLater(
          deactivatedWait,
          throwsA(isA<LxCancelledException>()),
        );

        computed.addListener(listener);
        final closedWait = computed.wait;
        final closeFuture = computed.close();
        await expectLater(closedWait, throwsA(isA<LxCancelledException>()));
        await expectLater(computed.wait, throwsA(isA<LxCancelledException>()));

        gate.complete(1);
        await closeFuture;
      },
    );

    test('returns final settled value when waited after close', () async {
      final computed = LxComputed.async(() async => 42);
      expect(await computed.wait, 42);
      await computed.close();
      expect(await computed.wait, 42);
    });
  });
}
