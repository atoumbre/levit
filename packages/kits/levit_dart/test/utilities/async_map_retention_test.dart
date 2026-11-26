import 'dart:async';
import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

void main() {
  test(
    'invalidation refreshes active entries and evicts inactive handles',
    () async {
      var builds = 0;
      final family = LevitAsyncMap<int, int>((_, _) => ++builds);
      final active = family.entry(1);
      void listener() {}
      active.addListener(listener);
      final inactive = family.entry(2);
      expect(() => family.evict(1), throwsStateError);
      await Future.wait([family.fetch(1), family.fetch(2)]);
      expect(await family.invalidate(1), isTrue);
      expect(active.value.lastValue, 3);
      expect(await family.invalidate(2), isTrue);
      expect(inactive.isClosed, isTrue);
      expect(family.containsKey(2), isFalse);
      expect(await family.invalidate(99), isFalse);
      active.removeListener(listener);
      await family.close();
    },
  );

  test(
    'LRU bounds inactive entries while active entries stay pinned',
    () async {
      final family = LevitAsyncMap<int, int>(
        (key, _) => key,
        maxInactiveEntries: 2,
      );
      final pinned = family.entry(-1);
      pinned.addListener(() {});
      final oldest = family.entry(1);
      final second = family.entry(2);
      family.entry(1); // Touch makes key 2 least recently used.
      family.entry(3);
      expect(second.isClosed, isTrue);
      expect(oldest.isClosed, isFalse);
      expect(pinned.isClosed, isFalse);
      expect(family.length, 3);
      await family.close();
    },
  );

  test(
    'inactive grace eviction closes handles without evicting a newly active entry',
    () async {
      final family = LevitAsyncMap<int, int>(
        (key, _) => key,
        gracePeriod: Duration.zero,
      );
      final inactive = family.entry(1);
      final active = family.entry(2);
      void listener() {}
      active.addListener(listener);
      await Future<void>.delayed(Duration.zero);
      expect(inactive.isClosed, isTrue);
      expect(active.isClosed, isFalse);
      active.removeListener(listener);
      await Future<void>.delayed(Duration.zero);
      expect(active.isClosed, isTrue);
      await family.close();
    },
  );

  test(
    'zero grace protects an admitted fetch until the caller receives data',
    () async {
      final started = Completer<void>();
      final finish = Completer<int>();
      final map = LevitAsyncMap<int, int>((_, _) {
        started.complete();
        return finish.future;
      }, gracePeriod: Duration.zero);
      final fetch = map.fetch(1);
      await started.future;
      await Future<void>.delayed(Duration.zero);
      expect(map.peek(1), isNotNull);
      finish.complete(5);
      expect(await fetch, 5);
      await Future<void>.delayed(Duration.zero);
      expect(map.peek(1), isNull);
      await map.close();
    },
  );
  test(
    'retention configuration, key privacy, noncreating lookups and invalidateAll',
    () async {
      expect(
        () => LevitAsyncMap<int, int>((k, _) => k, maxInactiveEntries: 0),
        throwsRangeError,
      );
      expect(
        () => LevitAsyncMap<int, int>(
          (k, _) => k,
          gracePeriod: const Duration(seconds: -1),
        ),
        throwsArgumentError,
      );
      final map = LevitAsyncMap<int, int>(
        (k, _) => k,
        name: 'numbers',
        debugKey: (_) => throw StateError('private'),
      );
      await map.refresh(1);
      final entry = map.entry(1);
      expect(map.peek(2), isNull);
      expect(map.keys, [1]);
      expect(await map.evict(2), false);
      await map.invalidateAll();
      expect(entry.isClosed, true);
      expect(() => entry.addListener(() {}), throwsStateError);
      expect(() => entry.value, throwsStateError);
      await map.close();
    },
  );

  test(
    'shared grace timer retires multiple due inactive entries and entry reports isReplacing during refresh',
    () async {
      var calls = 0;
      final map = LevitAsyncMap<int, int>((key, _) async {
        if (key == 10) {
          calls++;
          return calls * 10;
        }
        return key;
      }, gracePeriod: Duration.zero);

      final inactiveA = map.entry(1);
      final inactiveB = map.entry(2);
      await Future<void>.delayed(Duration.zero);
      expect(inactiveA.isClosed, isTrue);
      expect(inactiveB.isClosed, isTrue);

      final replacingEntry = map.entry(10);
      var sawReplacing = false;
      void listener() {
        if (replacingEntry.isReplacing) sawReplacing = true;
      }

      replacingEntry.addListener(listener);
      expect(await map.fetch(10), 10);

      await map.refresh(10);
      expect(sawReplacing, isTrue);
      expect(replacingEntry.isReplacing, isFalse);
      expect(replacingEntry.value.lastValue, 20);

      replacingEntry.removeListener(listener);
      await map.close();
    },
  );
}
