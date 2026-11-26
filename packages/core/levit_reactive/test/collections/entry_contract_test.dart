import 'dart:async';
import 'dart:collection';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';
import 'package:levit_reactive/spi.dart';

class _EntryNames extends LevitReactiveMiddleware {
  final names = <String?>[];
  @override
  void Function(LxReactive)? get onInit => (value) => names.add(value.name);
}

void main() {
  test(
    'two positions have distinct redacted diagnostic names and deliveries',
    () async {
      final list = LxList(initial: [1, 2], name: 'rows');
      final hook = _EntryNames();
      LevitReactiveMiddleware.add(hook);
      addTearDown(LevitReactiveMiddleware.clear);
      final hits = [0, 0];
      for (var i = 0; i < 2; i++) {
        list.entry(i).addListener(() => hits[i]++);
      }
      expect(hook.names.toSet().length, 2);
      expect(hook.names, everyElement(startsWith('rows[')));
      list[1] = 3;
      expect(hits, [0, 1]);
      await list.close();
    },
  );

  test('mixed depth batch delivers shallow observers first', () async {
    final shallow = 1.lx, deep = 1.lx;
    LxSpi.setGraphDepth(deep, 3);
    final delivered = <String>[];
    deep.addListener(() => delivered.add('deep'));
    shallow.addListener(() => delivered.add('shallow'));
    Lx.batch(() {
      deep.refresh();
      shallow.refresh();
    });
    expect(delivered, ['shallow', 'deep']);
    await shallow.close();
    await deep.close();
  });

  test(
    'switching the sole address detaches the old channel immediately',
    () async {
      final source = [1, 2].lx;
      var index = 0;
      final selected = LxComputed(() => source[index]);
      var updates = 0;
      selected.addListener(() {
        selected.value;
        updates++;
      });
      index = 1;
      source[0] = 6;
      expect(selected.value, 2);
      source[0] = 7;
      expect(updates, 1);
      expect(source.observedChannelCount, 1);
      await selected.close();
      expect(source.observedChannelCount, 0);
      await source.close();
    },
  );

  test(
    'parent joins retiring and active channel failures on reentrant close',
    () async {
      final list = [10, 20].lx;
      final retired = list.entry(0);
      void listen() {}
      retired.addListener(listen);
      list.entry(1).addListener(listen);
      final failures = <Object>[];
      Future<void>? closing;
      final hook = _EntryDisposal((value) {
        if (identical(value, list)) return;
        final failure = StateError('channel ${value.id}');
        failures.add(failure);
        closing ??= list.close();
        throw failure;
      });
      LevitReactiveMiddleware.add(hook);
      addTearDown(LevitReactiveMiddleware.clear);
      retired.removeListener(listen);
      expect(identical(closing, list.close()), isTrue);
      await expectLater(
        closing,
        throwsA(
          isA<LxCleanupException>().having(
            (e) => e.failures.map((f) => f.error),
            'both channels',
            unorderedEquals(failures),
          ),
        ),
      );
      expect(failures.length, 2);
      expect(list.observedChannelCount, 0);
    },
  );

  test(
    'a large failed batch releases queued observers for the next batch',
    () async {
      final values = List.generate(4100, (i) => i.lx);
      var delivered = 0;
      void broken() => throw StateError('listener');
      values.first.addListener(broken);
      values.last.addListener(() => delivered++);
      expect(
        () => Lx.batch(() {
          for (final value in values) {
            value.refresh();
          }
        }),
        throwsStateError,
      );
      values.first.removeListener(broken);
      Lx.batch(() => values.last.refresh());
      expect(delivered, 1);
      for (final value in values) {
        await value.close();
      }
    },
  );

  for (final fixed in [true, false]) {
    test(
      'delayed and repeated activation reconnect retired channels (static=$fixed)',
      () async {
        final map = <int, int>{1: 0}.lx;
        final selected = LxComputed(() => map[1]!, staticDeps: fixed);
        await Future<void>.delayed(Duration.zero);
        expect(map.observedChannelCount, 0);
        map[1] = 2;
        void listen() {
          selected.value;
        }

        selected.addListener(listen);
        expect(selected.value, 2);
        map[1] = 3;
        expect(selected.value, 3);
        selected.removeListener(listen);
        await Future<void>.delayed(Duration.zero);
        selected.addListener(listen);
        map[1] = 4;
        expect(selected.value, 4);
        await selected.close();
        await map.close();
      },
    );
  }
  test(
    'post-await capture, same-length key reorder and exceptional update',
    () async {
      final m = <String, int>{'a': 1, 'b': 2}.lx;
      final derived = LxAsyncComputed(() async {
        await Future<void>.value();
        return (m['a'] ?? 0) + Lx.untracked(() => m['b'] ?? 0);
      });
      derived.addListener(() {});
      expect(await derived.wait, 3);
      m['b'] = 4;
      expect(await derived.wait, 3);
      m['a'] = 2;
      await Future<void>.delayed(Duration.zero);
      expect(await derived.wait, 6);
      final order = LxComputed(() => m.keys.join());
      expect(order.value, 'ab');
      m.updateValue((_) => {'b': 4, 'a': 2});
      expect(order.value, 'ba');
      expect(
        () => m.updateValue((old) {
          old.remove('a');
          throw StateError('partial');
        }),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(await derived.wait, 4);
      await derived.close();
      await order.close();
      await m.close();
    },
  );
  test(
    'bulk writes, direct listeners and streams release their addresses',
    () async {
      final m = <int, int>{1: 2, 2: 3}.lx;
      final view = m.entry(2);
      var n = 0;
      void notify() {
        n++;
      }

      view.addListener(notify);
      m.updateAll((_, v) => v + 1);
      m.addEntries([const MapEntry(2, 4)]);
      expect(n, 2);
      view.removeListener(notify);
      expect(m.observedChannelCount, 0);
      expect(view.id, greaterThanOrEqualTo(0));
      await m.close();
      expect(() => view.value, throwsStateError);
      expect(await view.stream.isEmpty, true);
      expect(() => view.addListener(notify), throwsStateError);
      final list = [1, 2, 3].lx;
      final item = list.entry(1);
      item.addListener(notify);
      list[1] = 2;
      list.remove(1);
      Iterable<int> input() sync* {
        yield 7;
        yield 8;
      }

      list.setAll(0, input());
      expect(item.value, 8);
      expect(n, 5);
      expect(list.asMap().keys, [0, 1]);
      expect(list.asMap()[-1], isNull);
      await list.close();
    },
  );
  test(
    'key value, membership, shape and aggregate are distinct dependencies',
    () async {
      final m = <int, int?>{}.lx;
      final entry = m.entry(7);
      var element = 0, presence = 0, shape = 0, aggregate = 0;
      entry.addListener(() => element++);
      final member = LxComputed(() {
        presence++;
        return m.containsKey(7);
      });
      final keys = m.keys;
      final structure = LxComputed(() {
        shape++;
        return keys.join(',');
      });
      for (final observable in [member, structure]) {
        observable.addListener(() {
          observable.value;
        });
        observable.value;
      }
      m.addListener(() => aggregate++);
      m[42] = 1;
      m[42] = 2;
      expect([element, presence, shape, aggregate], [0, 1, 2, 2]);
      m[7] = null;
      expect(entry.exists, true);
      expect(entry.value, isNull);
      m[7] = null;
      expect([element, presence, shape, aggregate], [2, 2, 3, 4]);
      m.remove(7);
      expect(entry.exists, false);
      m[7] = 8;
      expect(entry.value, 8);
      await member.close();
      await structure.close();
      await m.close();
      expect(entry.isClosed, true);
    },
  );
  test('custom equality and partially failing bulk writes', () async {
    final backing = LinkedHashMap<String, int>(
      equals: (a, b) => a.toLowerCase() == b.toLowerCase(),
      hashCode: (k) => k.toLowerCase().hashCode,
    );
    final m = LxMap(initial: backing);
    final seen = <int?>[];
    final view = m.entry('X');
    final sub = view.stream.listen(seen.add);
    Iterable<MapEntry<String, int>> changes() sync* {
      yield const MapEntry('x', 3);
      throw StateError('input failed');
    }

    expect(() => m.addEntries(changes()), throwsStateError);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [3]);
    await sub.cancel();
    await m.close();
  });
  test(
    'list views follow positions, including absence, ranges and backed views',
    () async {
      final list = <int?>[1, 2, 3].lx;
      final view = list.entry(2);
      final seen = <int?>[];
      view.addListener(() => seen.add(view.value));
      final cast = list.cast<num?>();
      final byIndex = list.asMap();
      final odds = list.where((n) => n?.isOdd ?? false);
      final derived = LxComputed(() => odds.length + (byIndex[2] ?? 0));
      derived.addListener(() {
        derived.value;
      });
      expect(derived.value, 5);
      cast[0] = 4;
      expect(seen, isEmpty);
      list.insert(0, 9);
      expect(seen, [2]);
      list.replaceRange(0, 4, [null]);
      expect(view.exists, false);
      list.addAll([5, null]);
      expect(view.exists, true);
      expect(seen, [2, null, null]);
      expect(() => list[-1], throwsRangeError);
      expect(() => list.entry(-1), throwsRangeError);
      expect(() => byIndex[0] = 5, throwsUnsupportedError);
      await derived.close();
      await list.close();
    },
  );

  test('batched dynamic addresses retire after reconciliation', () async {
    final map = <int, int>{1: 10, 2: 20, 3: 30}.lx;
    final key = 1.lx;
    for (var k = 0; k < 100; k++) {
      map[k];
      map.entry(k).value;
    }
    expect(map.observedChannelCount, 0);
    var runs = 0;
    final result = LxComputed(() {
      runs++;
      return (map[key.value] ?? 0) + (map[3] ?? 0);
    });
    result.addListener(() => result.value);
    expect(result.value, 40);
    expect(map.observedChannelCount, 2);
    Lx.batch(() {
      map[1] = 11;
      Lx.batch(() => map[3] = 31);
    });
    expect(result.value, 42);
    key.value = 74;
    await Future<void>.delayed(Duration.zero);
    expect(map.observedChannelCount, 2);
    final prior = runs;
    map[1] = 12;
    expect(runs, prior);
    map[74] = 4;
    expect(result.value, 35);
    await result.close();
    await key.close();
    await Future<void>.delayed(Duration.zero);
    expect(map.observedChannelCount, 0);
    await map.close();
  });
  test(
    'key equality follows replacement backing; update, bind, refresh share publication',
    () async {
      final x = String.fromCharCodes([120]), y = String.fromCharCodes([120]);
      expect(identical(x, y), false);
      final map = <String, int>{x: 1}.lx;
      final a = map.entry(x), b = map.entry(y);
      var aa = 0, bb = 0;
      a.addListener(() => aa++);
      b.addListener(() => bb++);
      map[x] = 2;
      expect([aa, bb], [1, 1]);
      map.value = Map<String, int>.identity()..[x] = 2;
      expect([aa, bb], [1, 2]);
      expect(b.exists, false);
      map.updateValue((m) => m..[y] = 4);
      expect([aa, bb], [1, 3]);
      map.value[x] = 3;
      map.refresh();
      expect([aa, bb], [2, 4]);
      final incoming = StreamController<Map<String, int>>();
      map.bind(incoming.stream);
      incoming.add({x: 5});
      await Future<void>.delayed(Duration.zero);
      expect([a.value, b.value], [5, 5]);
      await incoming.close();
      await map.close();
    },
  );
  test(
    'positional shifts notify duplicate values and partial fixed-list writes survive failure',
    () async {
      final list = <int>[1, 1, 1, 1].lx;
      final row = list.entry(2), absent = list.entry(50);
      var calls = 0, other = 0;
      row.addListener(() => calls++);
      absent.addListener(() => other++);
      list.insert(1, 1);
      list.removeRange(0, 1);
      list.fillRange(1, 3, 1);
      expect([calls, other], [3, 0]);
      final fixed = LxList(initial: List<int>.filled(3, 1));
      final view = fixed.entry(0);
      final events = <int?>[];
      final done = Completer<void>();
      view.stream.listen(events.add, onDone: done.complete);
      Iterable<int> values() sync* {
        yield 4;
        throw StateError('partial');
      }

      expect(() => fixed.setAll(0, values()), throwsStateError);
      expect(view.value, 4);
      expect(() => fixed.insert(0, 1), throwsUnsupportedError);
      await fixed.close();
      await done.future;
      expect(events, [4]);
      expect(view.isClosed, true);
      await list.close();
    },
  );
}

class _EntryDisposal extends LevitReactiveMiddleware {
  _EntryDisposal(this.onClose);
  final void Function(LxReactive value) onClose;
  @override
  LevitReactiveOnDispose get onDispose =>
      (next, value) => () {
        next();
        onClose(value);
      };
}
