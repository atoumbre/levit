// Same workloads compile on both revisions. Timing excludes setup and cleanup.
import 'dart:convert';
import 'package:levit_reactive/levit_reactive.dart';

Future<void> main() async {
  const size = 128;
  final results = <String, Object>{};
  for (final kind in ['sparseMap', 'sparseIndex', 'shift', 'bulk', 'churn']) {
    final samples = <int>[], calls = <int>[];
    for (var round = 0; round < 11; round++) {
      final map = <int, int>{for (var n = 0; n < size; n++) n: n}.lx;
      final list = List<int>.generate(size, (i) => i).lx;
      final readers = <LxComputed<int>>[];
      var runs = 0;
      LxComputed<int> observe(int i) {
        final c = LxComputed(() {
          runs++;
          return kind == 'sparseIndex' || kind == 'shift' ? list[i] : map[i]!;
        });
        c.addListener(() {
          c.value;
        });
        return c;
      }

      if (kind != 'churn') {
        for (var n = 0; n < size; n++) {
          readers.add(observe(n));
        }
      }
      runs = 0;
      final timer = Stopwatch()..start();
      for (var n = 0; n < 256; n++) {
        final index = n % size;
        switch (kind) {
          case 'sparseMap':
            map[index] = n + size;
          case 'sparseIndex':
            list[index] = n + size;
          case 'shift':
            list.insert(32, n);
            list.removeAt(32);
          case 'bulk':
            map.addAll({index: n + size, (index + 1) % size: n + size + 1});
          case 'churn':
            await observe(index).close();
        }
      }
      timer.stop();
      if (round >= 2) {
        samples.add(timer.elapsedMicroseconds);
        calls.add(runs);
      }
      for (final c in readers) {
        await c.close();
      }
      await map.close();
      await list.close();
    }
    results[kind] = {'samplesUs': samples, 'computedRuns': calls};
  }
  print(jsonEncode(results));
}
