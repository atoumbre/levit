import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

// Use a subclass to access the protected member maybeNotifyGraphChange
class TestComputed extends LxComputed<int> {
  TestComputed() : super(() => 0);

  void triggerGraphChangeWithList() {
    // Calling the protected method with a List to hit the fast-path in _ComputedBase
    maybeNotifyGraphChange([0.lx]);
  }
}

void main() {
  test('LxComputed handles List in graph change notification', () {
    final computed = TestComputed();
    computed.triggerGraphChangeWithList();
  });
}
