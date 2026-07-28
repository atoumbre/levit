import 'dart:async';
import 'dart:math';

import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('LxAsyncComputed exhaustLatest', () {
    test('coalesces changes into exactly one non-overlapping trailing run',
        () async {
      final source = 0.lx;
      final gates = <Completer<void>>[];
      final captured = <int>[];
      var active = 0;
      var maxActive = 0;

      final computed = LxComputed.async<int>(
        () async {
          final current = source.value;
          captured.add(current);
          active++;
          maxActive = max(maxActive, active);
          final gate = Completer<void>();
          gates.add(gate);
          await gate.future;
          active--;
          return current;
        },
        concurrency: LxAsyncConcurrency.exhaustLatest,
      );
      void listener() {}
      computed.addListener(listener);

      expect(gates, hasLength(1));
      source.value = 1;
      source.value = 2;
      source.value = 3;
      expect(gates, hasLength(1));

      gates.first.complete();
      await _flush();

      expect(gates, hasLength(2));
      expect(captured, <int>[0, 3]);
      expect(maxActive, 1);

      gates.last.complete();
      await _flush();
      expect(computed.status, const LxSuccess<int>(3));
      computed.close();
      source.close();
    });

    test('a failed execution still admits the trailing run', () async {
      final source = 0.lx;
      final gates = <Completer<void>>[];
      final captured = <int>[];

      final computed = LxComputed.async<int>(
        () async {
          final current = source.value;
          captured.add(current);
          final gate = Completer<void>();
          gates.add(gate);
          await gate.future;
          return current;
        },
        concurrency: LxAsyncConcurrency.exhaustLatest,
      );
      void listener() {}
      computed.addListener(listener);

      source.value = 4;
      gates.first.completeError(StateError('first failed'));
      await _flush();

      expect(gates, hasLength(2));
      expect(captured, <int>[0, 4]);
      gates.last.complete();
      await _flush();
      expect(computed.status, const LxSuccess<int>(4));

      computed.close();
      source.close();
    });

    test('disposal suppresses a requested trailing run', () async {
      final source = 0.lx;
      final gate = Completer<void>();
      var runs = 0;
      final computed = LxComputed.async<int>(
        () async {
          runs++;
          final current = source.value;
          await gate.future;
          return current;
        },
        concurrency: LxAsyncConcurrency.exhaustLatest,
      );
      void listener() {}
      computed.addListener(listener);
      source.value = 1;

      computed.close();
      gate.complete();
      await _flush();

      expect(runs, 1);
      source.close();
    });
  });

  group('LxWorker exhaustLatest', () {
    test('uses the latest source value for one trailing callback', () async {
      final source = 0.lx;
      final gates = <Completer<void>>[];
      final seen = <int>[];
      var active = 0;
      var maxActive = 0;

      final worker = LxWorker<int>(
        source,
        (value) async {
          seen.add(value);
          active++;
          maxActive = max(maxActive, active);
          final gate = Completer<void>();
          gates.add(gate);
          await gate.future;
          active--;
        },
        concurrency: LxAsyncConcurrency.exhaustLatest,
      );

      source.value = 1;
      source.value = 2;
      source.value = 3;
      expect(gates, hasLength(1));

      gates.first.complete();
      await _flush();

      expect(gates, hasLength(2));
      expect(seen, <int>[1, 3]);
      expect(maxActive, 1);

      gates.last.complete();
      await _flush();
      worker.close();
      source.close();
    });

    test('processing errors do not discard the trailing callback', () async {
      final source = 0.lx;
      final first = Completer<void>();
      final seen = <int>[];
      final errors = <Object>[];

      final worker = LxWorker<int>(
        source,
        (value) async {
          seen.add(value);
          if (value == 1) await first.future;
        },
        concurrency: LxAsyncConcurrency.exhaustLatest,
        onProcessingError: (error, _) => errors.add(error),
      );

      source.value = 1;
      source.value = 2;
      first.completeError(StateError('worker failed'));
      await _flush();

      expect(seen, <int>[1, 2]);
      expect(errors.single, isA<StateError>());
      worker.close();
      source.close();
    });
  });
}
