import 'package:flutter_test/flutter_test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Stress Test: Collections', () {
    test('LxList Bulk Assign - 1M items', () {
      print('[Description] Tests performance of assigning a large list.');
      final list = <int>[].lx;
      final largeData = List.generate(1000000, (i) => i);

      final sw = Stopwatch()..start();
      list.value = largeData;
      sw.stop();

      expect(list.length, 1000000);
      print('Assigned 1M items to LxList in ${sw.elapsedMilliseconds}ms');

      list.close();
    });

    test('LxList Mutation Burst - 10k random ops', () {
      print('[Description] Tests rapid add/remove/insert operations.');
      final list = List.generate(10000, (i) => i).lx;
      const ops = 10000;

      final sw = Stopwatch()..start();
      for (var i = 0; i < ops; i++) {
        final op = i % 3;
        if (op == 0) {
          list.add(i);
        } else if (op == 1 && list.isNotEmpty) {
          list.removeAt(0);
        } else if (list.isNotEmpty) {
          list[0] = i;
        }
      }
      sw.stop();

      final opsPerMs = ops / sw.elapsedMilliseconds;
      print(
          'Performed $ops mutations in ${sw.elapsedMilliseconds}ms (${opsPerMs.toStringAsFixed(0)} ops/ms)');

      list.close();
    });

    test('LxMap Bulk Insert - 100k entries', () {
      print('[Description] Tests mass insertion into LxMap.');
      final map = LxMap<String, int>({});
      const count = 100000;

      final sw = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        map['key_$i'] = i;
      }
      sw.stop();

      expect(map.length, count);
      print('Inserted $count entries in ${sw.elapsedMilliseconds}ms');

      // Test clear
      sw.reset();
      sw.start();
      map.clear();
      sw.stop();
      print('Cleared $count entries in ${sw.elapsedMicroseconds}us');

      map.close();
    });

    test('LxMap Update Flood - 10k key updates', () {
      print('[Description] Tests rapidly updating existing map values.');
      final map = LxMap<String, int>({});
      const keyCount = 10000;

      // Pre-populate
      for (var i = 0; i < keyCount; i++) {
        map['key_$i'] = 0;
      }

      var notifyCount = 0;
      map.addListener(() => notifyCount++);

      final sw = Stopwatch()..start();
      for (var i = 0; i < keyCount; i++) {
        map['key_$i'] = i + 1;
      }
      sw.stop();

      print(
          'Updated $keyCount keys in ${sw.elapsedMilliseconds}ms ($notifyCount notifications)');

      map.close();
    });

    test('Collection Computed Propagation', () {
      print('[Description] Tests computed that observes collection changes.');
      final list = <int>[].lx;
      final sum = LxComputed(() => list.fold<int>(0, (a, b) => a + b));

      var computeCount = 0;
      sum.addListener(() => computeCount++);

      final sw = Stopwatch()..start();
      for (var i = 1; i <= 10000; i++) {
        list.add(i);
      }
      final result = sum.value;
      sw.stop();

      // Sum of 1..10000 = 50005000
      expect(result, 50005000);
      print(
          'Added 10k items, computed sum=$result in ${sw.elapsedMilliseconds}ms');
      print('Compute notifications: $computeCount');

      list.close();
      sum.close();
    });
  });
}
