import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test(
    'stable handle keeps direct, computed and worker subscriptions across refresh',
    () async {
      var generation = 0;
      final resource = LxResource<int, LxVar<int>>(() => (++generation).lx);
      final handle = resource;
      handle.value;
      final previousResource = handle.producer;
      final computed = LxComputed(() => handle.value * 10);
      final changes = <int>[];
      computed.addListener(() => changes.add(computed.value));
      final watched = <int>[];
      final worker = LxWorker(handle, watched.add);
      var direct = 0;
      handle.addListener(() => direct++);
      await resource.refresh();

      expect(previousResource.isDisposed, isTrue);
      expect(handle.producer, isNot(same(previousResource)));
      expect(computed.value, 20);
      expect(changes, contains(20));
      expect(watched, contains(2));
      expect(direct, greaterThanOrEqualTo(2));
      handle.producer.value = 3;
      expect(computed.value, 30);
      expect(watched.last, 3);
      await worker.close();
      await computed.close();
      await resource.close();
      expect(handle.isClosed, isTrue);
      expect(() => handle.value, throwsStateError);
    },
  );

  test(
    'refresh drains old producer, retains null and joins concurrent replacement',
    () async {
      final pending = Completer<int?>();
      var builds = 0;
      final resource = LxResource<LxStatus<int?>, LxFuture<int?>>(() {
        builds++;
        return builds == 1
            ? LxFuture(pending.future, initial: 5)
            : LxFuture(Future.value(null));
      });
      final handle = resource;
      handle.value;
      final first = resource.refresh();
      expect(identical(first, resource.refresh()), isTrue);
      expect(handle.isReplacing, isTrue);
      expect(handle.value.valueOrNull, 5);
      expect(() => handle.producer, throwsStateError);
      expect(builds, 1);
      pending.complete(99);
      await first;
      await handle.producer.wait;
      expect(builds, 2);
      expect(handle.value, isA<LxSuccess<int?>>());
      expect(handle.value.valueOrNull, isNull);
      await resource.close();
    },
  );

  test(
    'failed refresh remains observable and permits recovery on the same handle',
    () async {
      var fail = false;
      var builds = 0;
      final resource = LxResource<int, LxVar<int>>(() {
        if (fail) throw StateError('fetch failed');
        return (++builds).lx;
      });
      final handle = resource;
      handle.value;
      var signals = 0;
      handle.addListener(() => signals++);
      fail = true;
      await expectLater(resource.refresh(), throwsStateError);
      expect(signals, greaterThanOrEqualTo(2));
      expect(handle.refreshError, isA<StateError>());
      expect(handle.lastValue, 1);
      expect(() => handle.value, throwsStateError);
      fail = false;
      await resource.refresh();
      expect(handle.value, 2);
      expect(handle.refreshError, isNull);
      await resource.close();
    },
  );

  test(
    'closure during refresh drains old producer and never constructs replacement',
    () async {
      final gate = Completer<int>();
      var builds = 0;
      final resource = LxResource<LxStatus<int>, LxFuture<int>>(() {
        builds++;
        return LxFuture(gate.future);
      });
      final handle = resource;
      handle.value;
      final refresh = resource.refresh();
      final expected = expectLater(
        refresh,
        throwsA(isA<LxCancelledException>()),
      );
      var done = false;
      final close = resource.close().then((_) => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      gate.complete(1);
      await expected;
      await close;
      expect(builds, 1);
      expect(handle.isClosed, isTrue);
      expect(() => resource.value, throwsStateError);
    },
  );

  test(
    'resource reads are tracked and key diagnostics are opaque by default',
    () async {
      final resource = LxResource<int, LxVar<int>>(() => 1.lx, name: 'users');
      final handle = resource;
      handle.value;
      expect(handle.producer.name, equals('users'));
      expect(handle.producer.name, isNot(contains('private@example.com')));
      final selected = LxComputed(
        () => handle.isReplacing ? -1 : handle.producer.value,
      );
      selected.addListener(() {});
      expect(handle.isActive, isTrue);
      await resource.refresh();
      expect(selected.value, 1);
      await selected.close();
      await resource.close();
    },
  );
}
