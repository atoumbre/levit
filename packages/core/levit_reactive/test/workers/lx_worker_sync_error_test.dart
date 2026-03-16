import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class TestReactive<T> extends LxVar<T> { TestReactive(super.initial); }

void main() {
  test('LxWorker handles synchronous error', () {
    final reactive = TestReactive<int>(0);
    final watch = LxWorker(reactive, (val) => throw 'Sync Error');

    try {
      reactive.value = 1;
    } catch (e) {
      expect(e, 'Sync Error');
    }

    expect(watch.value.runCount, 1);
    expect(watch.value.error, 'Sync Error');
  });
}
