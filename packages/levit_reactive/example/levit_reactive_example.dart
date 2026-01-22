import 'package:levit_reactive/levit_reactive.dart';

void main() {
  // 1. Create a reactive variable
  final count = 0.lx;

  // 2. Create a computed value
  final doubleCount = (() => count.value * 2).lx;

  // 3. Watch for changes
  void listener() {
    print('Count: ${count.value}, Double: ${doubleCount.value}');
  }

  doubleCount.addListener(listener);

  // 4. Update value
  print('Incrementing...');
  count.value++; // Prints: Count: 1, Double: 2

  print('Incrementing again...');
  count.value++; // Prints: Count: 2, Double: 4

  // 5. Build an async computation
  final asyncValue = (() async {
    await Future.delayed(Duration(milliseconds: 100));
    return count.value * 10 + doubleCount.value;
  }).lx;

  // Listen to async status
  asyncValue.addListener(() {
    print('Async Status: ${asyncValue.status}');
  });

  // Trigger async update
  count.value++;
  print('count: ${count.value}');

  // Cleanup
  doubleCount.removeListener(listener);
  count.close();
}
