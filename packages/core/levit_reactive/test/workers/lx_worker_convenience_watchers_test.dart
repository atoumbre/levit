import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class TestReactive<T> extends LxVar<T> {
  TestReactive(super.initial);
}

void main() {
  test('Convenience watchers: isTrue, isFalse, isValue', () {
    final boolRx = TestReactive<bool>(false);
    final intRx = TestReactive<int>(0);

    var trueCount = 0;
    var falseCount = 0;
    var valueCount = 0;

    LxWorker.watchTrue(boolRx, () => trueCount++);
    LxWorker.watchFalse(boolRx, () => falseCount++);
    LxWorker.watchValue(intRx, 5, () => valueCount++);

    boolRx.value = true;
    expect(trueCount, 1);
    boolRx.value = false;
    expect(falseCount, 1);

    intRx.value = 3;
    intRx.value = 5;
    expect(valueCount, 1);
  });
}
