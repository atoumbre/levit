import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  test('LxComputed.async tracks dependencies after await with Zone support',
      () async {
    final preAwaitDependency = 0.lx;
    final postAwaitDependency = 0.lx;

    final computed = LxComputed.async(() async {
      // Access pre-await dependency
      final pre = preAwaitDependency.value;

      // Async gap
      await Future.delayed(Duration.zero);

      // Access post-await dependency
      final post = postAwaitDependency.value;

      return pre + post;
    });

    // Activate the computed signal by adding a listener
    computed.addListener(() {});

    // Wait for initial computation
    await Future.delayed(Duration(milliseconds: 50));
    expect(computed.value, isA<LxSuccess<int>>());
    expect(computed.computedValue, 0);

    // 1. Updating pre-await dependency SHOULD trigger recompute
    preAwaitDependency.value = 1;
    await Future.delayed(Duration(milliseconds: 50));
    expect(computed.computedValue, 1,
        reason: "Should track pre-await dependency");

    // 2. Updating post-await dependency SHOULD ALSO trigger recompute now
    postAwaitDependency.value = 1;
    await Future.delayed(Duration(milliseconds: 50));

    // Value should be 1 + 1 = 2
    expect(computed.computedValue, 2,
        reason: "Should track post-await dependency");
  });
}
