import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

/// Runs the `levit_flutter_core` example application.
void main() {
  runApp(const MyApp());
}

/// The root widget for the example application.
class MyApp extends StatelessWidget {
  /// Creates the root widget for the example application.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CounterPage(),
    );
  }
}

/// A controller that owns a single reactive counter value.
class CounterController extends LevitController {
  /// The current counter value.
  final count = 0.lx;

  /// Increments [count] by one.
  void increment() {
    count.value++;
  }
}

/// A page that displays and updates a counter using Levit widgets.
class CounterPage extends StatelessWidget {
  /// Creates the counter page.
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LScopedView.put(
      () => CounterController(),
      builder: (context, controller) => Scaffold(
        appBar: AppBar(title: const Text('Levit Flutter Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('You have pushed the button this many times:'),
              Text(
                '${controller.count.value}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: controller.increment,
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
