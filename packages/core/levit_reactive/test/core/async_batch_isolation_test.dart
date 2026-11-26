import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  for (final withMiddleware in [false, true]) {
    group('async isolation middleware=$withMiddleware', () {
      LevitReactiveMiddleware? middleware;
      setUp(() {
        if (withMiddleware) {
          middleware = Lx.addMiddleware(_PassThroughMiddleware());
        }
      });
      tearDown(() {
        if (middleware != null) Lx.removeMiddleware(middleware!);
      });
      for (final reverse in [false, true]) {
        test(
          'concurrent batches flush independently reverse=$reverse',
          () async {
            final a = 0.lx;
            final b = 0.lx;
            final outside = 0.lx;
            final events = <String>[];
            a.addListener(() => events.add('a'));
            b.addListener(() => events.add('b'));
            outside.addListener(() => events.add('outside'));
            final releaseA = Completer<void>();
            final releaseB = Completer<void>();
            final first = Lx.batchAsync(() async {
              a.value = 1;
              expect(Lx.isBatching, isTrue);
              await releaseA.future;
              a.value = 2;
            });
            final second = Lx.batchAsync(() async {
              b.value = 1;
              await releaseB.future;
              b.value = 2;
            });
            expect(Lx.isBatching, isFalse);
            outside.value = 1;
            expect(events, ['outside']);
            (reverse ? releaseB : releaseA).complete();
            await (reverse ? second : first);
            expect(events, ['outside', reverse ? 'b' : 'a']);
            (reverse ? releaseA : releaseB).complete();
            await (reverse ? first : second);
            expect(events, [
              'outside',
              reverse ? 'b' : 'a',
              reverse ? 'a' : 'b',
            ]);
            a.close();
            b.close();
            outside.close();
          },
        );
      }
      test(
        'concurrent batches share values but own notification boundaries',
        () async {
          final source = 0.lx;
          final values = <int>[];
          source.addListener(() => values.add(source.value));
          final firstRelease = Completer<void>();
          final secondRelease = Completer<void>();
          final first = Lx.batchAsync(() async {
            source.value = 1;
            await firstRelease.future;
          });
          final second = Lx.batchAsync(() async {
            source.value = 2;
            await secondRelease.future;
            source.value = 3;
          });
          firstRelease.complete();
          await first;
          expect(values, [2]);
          secondRelease.complete();
          await second;
          expect(values, [2, 3]);
          source.close();
        },
      );
      test(
        'listener failure closes the context and clears pending delivery',
        () async {
          final source = 0.lx;
          void fail() => throw StateError('listener');
          source.addListener(fail);
          await expectLater(
            Lx.batchAsync(() async {
              source.value = 1;
            }),
            throwsStateError,
          );
          expect(Lx.isBatching, isFalse);
          source.removeListener(fail);
          var delivered = 0;
          source.addListener(() => delivered++);
          source.value = 2;
          expect(delivered, 1);
          source.close();
        },
      );
      test('outside write to the same source is immediately visible', () async {
        final a = 0.lx;
        final values = <int>[];
        a.addListener(() => values.add(a.value));
        final release = Completer<void>();
        final work = Lx.batchAsync(() async {
          a.value = 1;
          await release.future;
        });
        a.value = 2;
        expect(values, [2]);
        release.complete();
        await work;
        expect(values, [2, 2]);
        a.close();
      });
      test('escaped work skips closed contexts', () async {
        final a = 0.lx;
        var changes = 0;
        a.addListener(() => changes++);
        final release = Completer<void>();
        late Future<void> escaped;
        await Lx.batchAsync(() async {
          escaped = release.future.then((_) {
            expect(Lx.isBatching, isFalse);
            a.value = 1;
          });
        });
        release.complete();
        await escaped;
        expect(changes, 1);
        a.close();
      });
      test('sync boundary returning a future closes immediately', () async {
        final source = 0.lx;
        final release = Completer<void>();
        final work = Lx.batch(() {
          source.value = 1;
          return release.future.then((_) {
            expect(Lx.isBatching, isFalse);
            source.value = 2;
          });
        });
        release.complete();
        await work;

        source.close();
      });
      test('escaped nested batch does not duplicate history', () async {
        final source = 0.lx;
        final release = Completer<void>();
        late Future<void> escaped;
        await Lx.batchAsync(() async {
          escaped = Lx.batchAsync(() async {
            source.value = 1;
            await release.future;
            source.value = 2;
          });
        });
        release.complete();
        await escaped;

        source.close();
      });
      test('escaped work finds an enclosing open context', () async {
        final source = 0.lx;
        var changes = 0;
        source.addListener(() => changes++);
        final release = Completer<void>();
        late Future<void> escaped;
        await Lx.batchAsync(() async {
          await Lx.batchAsync(() async {
            escaped = release.future.then((_) {
              expect(Lx.isBatching, isTrue);
              source.value = 1;
            });
          });
          release.complete();
          await escaped;
          expect(changes, 0);
        });
        expect(changes, 1);
        source.close();
      });
      test(
        'sync errors finish history and empty escaped batches add nothing',
        () async {
          final source = 0.lx;
          expect(
            () => Lx.batch(() {
              source.value = 1;
              throw StateError('sync');
            }),
            throwsStateError,
          );
          final release = Completer<void>();
          late Future<void> child;
          await Lx.batchAsync(() async {
            child = Lx.batchAsync(() async {
              source.value = 2;
              await release.future;
            });
          });
          release.complete();
          await child;
          source.close();
        },
      );
      test('nested failure flushes ordered diamond graph once', () async {
        final a = 1.lx;
        final b = LxComputed(() => a.value * 2)..addListener(() {});
        final c = LxComputed(() => a.value + 3)..addListener(() {});
        final total = LxComputed(() => b.value + c.value);
        final seen = <int>[];
        total.addListener(() => seen.add(total.value));
        await expectLater(
          Lx.batchAsync(() async {
            a.value = 2;
            await Lx.batchAsync(() async {
              Lx.batch(() {
                a.value = 3;
              });
              throw StateError('failure');
            });
          }),
          throwsStateError,
        );
        expect(seen, [12]);
        expect(Lx.isBatching, isFalse);
        a.value = 4;
        expect(seen.last, 15);

        total.close();
        b.close();
        c.close();
        a.close();
      });
    });
  }
}

class _PassThroughMiddleware extends LevitReactiveMiddleware {
  @override
  LevitReactiveOnSet get onSet => (next, reactive, change) => next;
  @override
  LevitReactiveOnBatch get onBatch => (next, change) => next;
}
