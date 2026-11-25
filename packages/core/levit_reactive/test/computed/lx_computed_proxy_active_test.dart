import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';
import 'package:levit_reactive/spi.dart';

void main() {
  test('LxComputed value getter succeeds when proxy is active', () {
    final source = 10.lx;
    final computed = LxComputed<int>(() => source.value * 2);
    final tracker = _MockObserver();
    LxSpi.proxy = tracker;
    try {
      expect(computed.value, 20);
    } finally {
      LxSpi.proxy = null;
    }
  });
}

class _MockObserver implements LevitReactiveObserver {
  @override
  void addNotifier(LevitReactiveNotifier notifier) {}
  @override
  void addReactive(LxReactive reactive) {}
}
