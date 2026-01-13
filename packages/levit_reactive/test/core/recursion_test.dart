import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  test('Deep recursion in batch does not overflow stack (Iterative Flush)', () {
    // This test verifies that cascading updates within a batch are handled iteratively.
    // If the implementation used recursion for each flush pass, this would stack overflow.

    const depth = 5000; // Deep enough to likely overflow stack if recursive
    final notifiers = List.generate(depth, (i) => 0.lx);

    // Chain: 0 -> 1 -> 2 ... -> depth-1
    for (var i = 0; i < depth - 1; i++) {
      notifiers[i].addListener(() {
        // Trigger next update
        notifiers[i + 1].value++;
      });
    }

    // Trigger the chain inside a batch
    // The batch will collect the first change (0).
    // On flush, 0 will notify, causing 1 to change.
    // 1's change will be added to _batchedNotifiers (since we are still in batch mode during flush).
    // The flush loop must pick up 1 and continue without recursing the function call.
    Lx.batch(() {
      notifiers[0].value++;
    });

    expect(notifiers.last.value, 1);
  });

  test('LxFuture.wait throws clear error when idle', () async {
    final futureRx = LxFuture<int>.idle();
    try {
      await futureRx.wait;
      fail('Should have thrown StateError');
    } catch (e) {
      expect(e, isA<StateError>());
      expect(e.toString(), contains('Call restart()'));
    }
  });
}
