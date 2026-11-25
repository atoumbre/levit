import 'dart:async';

import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';
import 'package:levit_reactive/spi.dart';

class DisposeHook extends LevitReactiveMiddleware {
  DisposeHook(this.action);
  final void Function(void Function(), LxReactive) action;
  @override
  LevitReactiveOnDispose get onDispose =>
      (next, reactive) =>
          () => action(next, reactive);
}

class ObservationHook extends LevitReactiveMiddleware
    implements LevitReactiveMetadataObserver {
  final metadata = <(String?, String?, bool)>[];
  final changes = <LevitReactiveChange<dynamic>>[];
  @override
  void onReactiveMetadata(LxReactive reactive) =>
      metadata.add((reactive.name, reactive.ownerId, reactive.isSensitive));
  @override
  LevitReactiveOnSet get onSet =>
      (next, reactive, change) => (value) {
        changes.add(change);
        next(value);
      };
}

void main() {
  tearDown(LevitReactiveMiddleware.clear);

  for (final before in [true, false]) {
    test(
      'middleware failure before=$before still drains the binding',
      () async {
        final gate = Completer<void>();
        final bindingError = StateError('binding');
        final middlewareError = StateError('middleware');
        final upstream = StreamController<int>(
          onCancel: () async {
            await gate.future;
            throw bindingError;
          },
        );
        final value = 0.lx..bind(upstream.stream);
        LevitReactiveMiddleware.add(
          DisposeHook((next, _) {
            if (!before) next();
            throw middlewareError;
          }),
        );
        var done = false;
        final closing = value.close();
        final checked = expectLater(
          closing,
          throwsA(
            isA<LxCleanupException>().having(
              (e) => e.failures.map((f) => f.error),
              'all failures',
              unorderedEquals([middlewareError, bindingError]),
            ),
          ),
        );
        unawaited(
          closing.then<void>(
            (_) => done = true,
            onError: (Object _) {
              done = true;
            },
          ),
        );
        expect(identical(closing, value.close()), isTrue);
        expect(value.isDisposed, isTrue);
        expect(() => value.bind(const Stream.empty()), throwsStateError);
        await Future<void>.delayed(Duration.zero);
        expect(done, isFalse);
        gate.complete();
        await checked;
        await upstream.close();
      },
    );
  }

  test(
    'async resource reports both observation and producer cleanup failures',
    () async {
      final gate = Completer<void>();
      final producerError = StateError('producer');
      final observationError = StateError('observation');
      final upstream = StreamController<int>(
        onCancel: () async {
          await gate.future;
          throw producerError;
        },
      );
      final value = LxStream(upstream.stream)..addListener(() {});
      LevitReactiveMiddleware.add(
        DisposeHook((next, _) {
          next();
          throw observationError;
        }),
      );
      final closing = value.close();
      final checked = expectLater(
        closing,
        throwsA(
          isA<LxCleanupException>().having(
            (e) => e.failures.map((f) => f.error),
            'all failures',
            unorderedEquals([producerError, observationError]),
          ),
        ),
      );
      gate.complete();
      await checked;
      await upstream.close();
    },
  );

  test(
    'worker rejects self-drain and cancellation remains cooperative',
    () async {
      final source = 0.lx;
      final started = Completer<void>();
      final finished = Completer<void>();
      late LxWorker<int> worker;
      worker = LxWorker.withContext(source, (_, context) async {
        context.throwIfCancelled();
        expect(() => worker.close(), throwsStateError);
        await expectLater(worker.drain(), throwsStateError);
        started.complete();
        await context.cancelled;
        expect(context.throwIfCancelled, throwsA(isA<LxCancelledException>()));
        finished.complete();
      });
      source.value++;
      await started.future;
      await worker.close();
      expect(finished.isCompleted, isTrue);
      expect(const LxCancelledException().toString(), contains('cancelled'));
      await source.close();
    },
  );

  test(
    'unbind drains errors and unobserved upstream errors reach the zone',
    () async {
      final cancellation = StateError('cancel');
      final event = StateError('event');
      final seen = <Object>[];
      final upstream = StreamController<int>(
        onCancel: () => throw cancellation,
      );
      final value = 0.lx;
      runZonedGuarded(() => value.bind(upstream.stream), (e, _) => seen.add(e));
      upstream.addError(event);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [event]);
      await expectLater(value.unbind(), throwsA(isA<LxCleanupException>()));
      await expectLater(value.close(), throwsA(isA<LxCleanupException>()));
      await upstream.close();
    },
  );

  test('cleanup errors flatten, deduplicate and retain immutable detail', () {
    final error = StateError('failure');
    final failure = AsyncError(error, StackTrace.current);
    final nested = LxCleanupException([failure]);
    final all = LxCleanupException([AsyncError(nested, null), failure]);
    expect(all.failures.single.error, same(error));
    expect(all.toString(), contains('1 failures'));
    expect(() => all.failures.clear(), throwsUnsupportedError);
  });

  test(
    'future previous success preserves explicit nullable presence',
    () async {
      final future = LxFuture<int?>(
        Future.value(null),
        previous: LxSuccess(null),
      );
      expect(future.hasLastValue, isTrue);
      expect(future.value.lastValue, isNull);
      expect(LxWaiting<int>(3).lastValue, 3);
      await future.close();
    },
  );

  test(
    'metadata changes and explicit restore operations notify consistently',
    () async {
      final hook = ObservationHook();
      LevitReactiveMiddleware.add(hook);
      final value = 0.lx;
      value
        ..ownerId = 'owner'
        ..ownerId = 'owner'
        ..name = 'count'
        ..name = 'count'
        ..isSensitive = true
        ..isSensitive = true;
      expect(hook.metadata, [
        (null, 'owner', false),
        ('count', 'owner', false),
        ('count', 'owner', true),
      ]);
      final seen = <int>[];
      value.stream.listen(seen.add);
      value.value = 1;
      hook.changes.last.restore!(0);
      Lx.batch(value.refresh);
      hook.changes.last.restore!(2);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [1, 0, 0, 2]);
      expect(value.value, 2);
      await value.close();
    },
  );
}
