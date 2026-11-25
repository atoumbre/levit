import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';
import 'package:levit_reactive/spi.dart';

class DefaultObserver extends LevitReactiveObserver {
  @override
  void addNotifier(LevitReactiveNotifier notifier) {}
}

void main() {
  test('LevitReactiveObserver default addReactive does nothing', () {
    final observer = DefaultObserver();
    final rx = LxVar(10);
    observer.addReactive(rx);
  });
}
