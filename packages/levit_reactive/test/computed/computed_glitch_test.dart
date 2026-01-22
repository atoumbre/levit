import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'dart:async';

void main() {
  test('computed chain glitch test (synchronous propagation check)', () async {
    const chainLength = 10; // Use smaller chain for test
    const updates = 100;

    final root = 0.lx;
    final chain = <LxComputed<int>>[];

    var currents = LxComputed(() => root.value);
    chain.add(currents);

    for (int i = 1; i < chainLength; i++) {
      final prev = currents;
      currents = LxComputed(() => prev.value + 1);
      chain.add(currents);
    }

    final endNode = chain.last;
    int listenerCallCount = 0;
    bool glitchDetected = false;
    int lastValue = -1;

    // Use synchronous listener to verify glitch freedom
    void checkGlitch() {
      listenerCallCount++;
      lastValue = endNode.value;
      if (lastValue != root.value + chainLength - 1) {
        glitchDetected = true;
      }
    }

    endNode.addListener(checkGlitch);

    for (int i = 1; i <= updates; i++) {
      root.value = i;
      // Allow any async tasks (though everything should be sync now)
      await Future.delayed(Duration.zero);
    }

    print('Notifications received: $listenerCallCount');
    print('Final value: $lastValue');
    print('Glitch detected: $glitchDetected');

    expect(listenerCallCount, updates,
        reason: 'Should receive one notification per update (no initial)');
    expect(lastValue, updates + chainLength - 1,
        reason: 'Final value should be correct');
    expect(glitchDetected, isFalse, reason: 'System should be glitch-free');

    endNode.removeListener(checkGlitch);
  });
}
