import 'package:levit_dart/levit_dart.dart';

// A business logic component
class CounterController extends LevitController {
  // Reactive state
  final count = 0.lx;

  // Computed state
  late final doubleCount = LxComputed(() => count.value * 2);

  @override
  void onInit() {
    super.onInit();
    print('CounterController initialized');
    // React to changes
    void listener() {
      print('Count changed to: ${count.value}');
    }

    count.addListener(listener);
    autoDispose(() => count.removeListener(listener));

    autoDispose(LxWatch(
        doubleCount, (value) => print('DoubleCount changed to: $value')));
  }

  @override
  void onClose() {
    print('CounterController disposed');
    super.onClose();
  }

  void increment() => count.value++;
}

void main() {
  print('--- App Start ---');

  // 1. Register the controller
  Levit.put(() => CounterController());

  // 2. Resolve the controller
  final controller = Levit.find<CounterController>();

  // 3. Interact
  controller.increment();
  controller.increment();

  print('Current count: ${controller.count.value}');
  print('Doubled: ${controller.doubleCount.value}');

  // 4. Cleanup (simulating app shutdown or scope destruction)
  print('\n--- App Shutdown ---');
  Levit.reset();
}
