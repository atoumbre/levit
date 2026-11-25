import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test(
    'latest worker cancels prior context and close drains both bodies',
    () async {
      final source = 0.lx;
      final gates = [Completer<void>(), Completer<void>()];
      final contexts = <LxExecutionContext>[];
      final finished = <int>[];
      final worker = LxWorker<int>.withContext(source, (value, context) async {
        contexts.add(context);
        try {
          await gates[value - 1].future;
        } finally {
          finished.add(value);
        }
      });
      source.value = 1;
      source.value = 2;
      expect(contexts.first.isCancelled, isTrue);
      expect(contexts.last.isCancelled, isFalse);
      var done = false;
      final closing = worker.close().then((_) => done = true);
      expect(contexts.last.isCancelled, isTrue);
      source.value = 3;
      gates.last.complete();
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      gates.first.complete();
      await closing;
      expect(finished, [2, 1]);
      expect(contexts, hasLength(2));
      await source.close();
    },
  );

  test(
    'future close waits for superseded as well as current operations',
    () async {
      final first = Completer<int>();
      final second = Completer<int>();
      final source = LxFuture(first.future);
      source.restart(second.future);
      var done = false;
      final closing = source.close().then((_) => done = true);
      second.complete(2);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      first.complete(1);
      await closing;
      expect(source.isDisposed, isTrue);
    },
  );

  test('worker conveniences retain asynchronous completion', () async {
    final source = false.lx;
    final gate = Completer<void>();
    final worker = LxWorker.watchTrue(source, () => gate.future);
    source.value = true;
    var done = false;
    final closing = worker.close().then((_) => done = true);
    await Future<void>.value();
    expect(done, isFalse);
    gate.complete();
    await closing;
    await source.close();
  });

  test(
    'stream close waits for asynchronous subscription cancellation',
    () async {
      final gate = Completer<void>();
      final stream = StreamController<int>(onCancel: () => gate.future);
      final reactive = LxStream(stream.stream);
      void listener() {}
      reactive.addListener(listener);
      var done = false;
      final closing = reactive.close().then((_) => done = true);
      await Future<void>.value();
      expect(done, isFalse);
      gate.complete();
      await closing;
      await stream.close();
    },
  );
  test(
    'binding replacement keeps subscribers and drains every upstream cancellation',
    () async {
      final firstGate = Completer<void>();
      final secondGate = Completer<void>();
      final first = StreamController<int>(onCancel: () => firstGate.future);
      final second = StreamController<int>(onCancel: () => secondGate.future);
      final value = 0.lx;
      final seen = <int>[];
      value.stream.listen(seen.add);
      value.bind(first.stream);
      first.add(1);
      await Future<void>.delayed(Duration.zero);
      value.bind(second.stream);
      second.add(2);
      first.add(99);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [1, 2]);
      var done = false;
      final closing = value.close().then((_) => done = true);
      secondGate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      firstGate.complete();
      await closing;
      await first.close();
      await second.close();
    },
  );
}
