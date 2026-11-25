import 'dart:async';

import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class _GraphObserverMiddleware extends LevitReactiveMiddleware {
  int graphChanges = 0;

  @override
  void Function(LxReactive reactive, List<LxReactive> dependencies)?
  get onGraphChange => (_, _) {
    graphChanges++;
  };
}

class _Box {
  final int id;
  final int generation;
  const _Box(this.id, this.generation);

  @override
  bool operator ==(Object other) => other is _Box && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

void main() {
  group('LxComputed activation and error recovery', () {
    test('recomputes when dependencies mutate before first activation', () {
      final a = 1.lx;
      final doubled = LxComputed(() => a.value * 10);

      // Mutate before any listener attaches.
      a.value = 3;

      void listener() {}
      doubled.addListener(listener);
      expect(doubled.value, 30);

      a.value = 4;
      expect(doubled.value, 40);
      doubled.removeListener(listener);
      doubled.close();
    });

    test(
      'switches conditional dependencies when flipped before activation',
      () {
        final flag = false.lx;
        final left = 10.lx;
        final right = 20.lx;
        final selected = LxComputed(
          () => flag.value ? left.value : right.value,
        );

        flag.value = true;

        var notifications = 0;
        void listener() => notifications++;
        selected.addListener(listener);
        expect(selected.value, 10);

        left.value = 99;
        expect(selected.value, 99);
        expect(notifications, greaterThanOrEqualTo(1));

        selected.removeListener(listener);
        selected.close();
      },
    );

    test(
      'remains dirty after thrown recomputation and notifies on recovery',
      () {
        final divisor = 2.lx;
        final ratio = LxComputed(() => 10 ~/ divisor.value);
        var notifications = 0;
        void listener() => notifications++;
        ratio.addListener(listener);
        expect(ratio.value, 5);

        divisor.value = 0;
        expect(() => ratio.value, throwsUnsupportedError);
        // Second read must still throw rather than returning stale 5.
        expect(() => ratio.value, throwsUnsupportedError);

        final beforeRecovery = notifications;
        divisor.value = 5;
        expect(notifications, greaterThan(beforeRecovery));
        expect(ratio.value, 2);

        ratio.removeListener(listener);
        ratio.close();
      },
    );

    test('honors custom equals stricter than operator ==', () {
      final gen = 1.lx;
      final computed = LxComputed<_Box>(
        () => _Box(1, gen.value),
        equals: (a, b) => a.generation == b.generation,
        eager: true,
      );
      final seen = <int>[];
      void listener() => seen.add(computed.value.generation);
      computed.addListener(listener);

      gen.value = 2;
      expect(computed.value.generation, 2);
      expect(seen, [2]);

      computed.removeListener(listener);
      computed.close();
    });

    test(
      'avoids diamond glitches and duplicate notifications in eager and lazy graphs',
      () {
        final a = 1.lx;
        final b = LxComputed(() => a.value * 2);
        final c = LxComputed(() => a.value + b.value, eager: true);

        // Attach c before b so a's listener set sees c first if unordered.
        final eagerValues = <int>[];
        void cListener() => eagerValues.add(c.value);
        c.addListener(cListener);
        void bListener() {}
        b.addListener(bListener);

        a.value = 3;
        expect(eagerValues, [9]);

        Lx.batch(() {
          a.value = 5;
        });
        expect(eagerValues, [9, 15]);

        c.removeListener(cListener);
        b.removeListener(bListener);
        c.close();
        b.close();
      },
    );
  });

  group('LxAsyncComputed recovery, equality, and lifecycle', () {
    test(
      'recovers from LxError when retry returns the pre-error value',
      () async {
        final attempt = 1.lx;
        final computed = LxAsyncComputed<String>(() async {
          final current = attempt.value;
          if (current == 2) throw StateError('transient');
          return 'Alice';
        });

        void listener() {}
        computed.addListener(listener);
        await Future<void>.delayed(Duration.zero);
        expect(computed.status, isA<LxSuccess<String>>());
        expect(computed.status.valueOrNull, 'Alice');

        attempt.value = 2;
        await Future<void>.delayed(Duration.zero);
        expect(computed.status, isA<LxError<String>>());

        attempt.value = 3;
        await Future<void>.delayed(Duration.zero);
        expect(computed.status, isA<LxSuccess<String>>());
        expect(computed.status.valueOrNull, 'Alice');

        computed.removeListener(listener);
        await computed.close();
      },
    );

    test('honors custom equals stricter than operator ==', () async {
      final gen = 1.lx;
      final computed = LxAsyncComputed<_Box>(
        () async => _Box(1, gen.value),
        equals: (a, b) => a.generation == b.generation,
      );
      final seen = <int>[];
      void listener() {
        if (computed.status case LxSuccess<_Box>(:final value)) {
          seen.add(value.generation);
        }
      }

      computed.addListener(listener);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [1]);

      gen.value = 2;
      await Future<void>.delayed(Duration.zero);
      expect(seen, [1, 2]);

      computed.removeListener(listener);
      await computed.close();
    });

    test(
      'preserves post-await tracking of inactive computed when graph middleware is installed',
      () async {
        final middleware = _GraphObserverMiddleware();
        Lx.addMiddleware(middleware);
        addTearDown(() => Lx.removeMiddleware(middleware));

        final source = 1.lx;
        final inactiveSync = LxComputed(() => source.value * 2);
        final asyncDerived = LxAsyncComputed<int>(() async {
          await Future<void>.delayed(Duration.zero);
          return inactiveSync.value;
        });

        void listener() {}
        asyncDerived.addListener(listener);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(asyncDerived.status.valueOrNull, 2);

        source.value = 5;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(asyncDerived.status.valueOrNull, 10);

        asyncDerived.removeListener(listener);
        await asyncDerived.close();
        await inactiveSync.close();
      },
    );

    test(
      'does not execute compute if waiting listener closes it synchronously',
      () async {
        var runs = 0;
        late LxAsyncComputed<int> computed;
        computed = LxAsyncComputed<int>(
          () async {
            runs++;
            return 1;
          },
          initial: 0,
          showWaiting: true,
        );

        void listener() {
          if (computed.status is LxWaiting<int>) {
            unawaited(computed.close());
          }
        }

        computed.addListener(listener);
        await Future<void>.delayed(Duration.zero);
        expect(runs, 0);
        await computed.close();
      },
    );
  });
}
