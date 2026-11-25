import 'package:levit_dart/levit_dart.dart';

/// Sorting IDs preserves each entity's pending request and freshness.
Future<void> main() async {
  final order = LxList.from([2, 1]);
  final names = LevitAsyncMap<int, String>((id, _) => 'Item $id');
  try {
    final row = names.entry(order[0]);
    await Future.wait(order.map(names.fetch));
    order.sort();
    assert(identical(row, names.entry(order[1])));
    for (final id in order) {
      print(names[id].valueOrNull);
    }
  } finally {
    await names.close();
    await order.close();
  }
}
