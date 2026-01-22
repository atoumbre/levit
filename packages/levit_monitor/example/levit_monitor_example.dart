import 'package:levit_dart/levit_dart.dart';
import 'package:levit_monitor/levit_monitor.dart';

// A business logic component
class CounterController extends LevitController {
  // Reactive state
  final count = 0.lx.named("count");

  // Stream state
  final stream =
      LxStream(Stream.periodic(const Duration(seconds: 1), (count) => count++))
          .named("stream");

  // Computed state
  late final movingDoubleCount =
      LxComputed(() => count.value * (stream.valueOrNull ?? 0))
          .named("movingDoubleCount");

  @override
  void onInit() {
    print('CounterController initialized');
    super.onInit();

    final doubleCountWatcher = LxWatch(
      movingDoubleCount,
      (value) => print('DoubleCount changed to: $value'),
    ).named('doubleCountWatcher');

    autoDispose(doubleCountWatcher);
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

  // 0. Attach monitor
  LevitMonitor.attach(
      transport: ConsoleTransport(minLevel: LevitLogLevel.trace));

  // 1. Register the controller
  Levit.put(() => CounterController());

  // 2. Resolve the controller
  final controller = Levit.find<CounterController>();

  // 3. Interact
  controller.increment();
  controller.increment();

  // 4. Cleanup (simulating app shutdown or scope destruction)
  print('\n--- App Shutdown ---');
  Levit.reset();
}
