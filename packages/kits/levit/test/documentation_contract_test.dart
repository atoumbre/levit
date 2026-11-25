import 'package:levit/levit.dart';
import 'package:test/test.dart';

class CounterController extends LevitController {
  final count = 0.lx;
  void increment() => count.value++;
}

void main() {
  test('documented Dart bootstrap, controller, and store patterns', () async {
    Levit.enableAutoLinking();
    final counterStore = LevitStore((ref) => ref.own(0.lx));
    late CounterController controller;
    late LxVar<int> stored;
    await Levit.runInScope(() {
      controller = Levit.put(CounterController.new);
      controller.increment();
      stored = counterStore.find(localOnly: true);
      stored.value++;
      expect(controller.count(), 1);
      expect(stored(), 1);
    });
    expect(controller.count.isDisposed, isTrue);
    expect(stored.isDisposed, isTrue);
    Levit.disableAutoLinking();
  });
}
