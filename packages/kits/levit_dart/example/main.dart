import 'dart:async';
import 'package:levit_dart/levit_dart.dart';

// -----------------------------------------------------------------------------
// Controller Implementations
// -----------------------------------------------------------------------------

class TaskExampleController extends LevitController with LevitTasksMixin {}

class SelectionExampleController<T> extends LevitController
    with LevitSelectionMixin<T> {}

class TimeExampleController extends LevitController with LevitTimeMixin {}

class LoopExampleController extends LevitController
    with LevitLoopExecutionMixin {}

/// A comprehensive example demonstrating the high-level utility mixins
/// provided by the `levit_dart` package.
void main() async {
  // Example runs in an isolated root scope and disposes it at the end.
  final scope = LevitScope.root();

  print('--- Levit Dart Example ---');

  print('\n1. TasksMixin Demo - Execution Queue & Retries');
  final taskController = scope.put(() => TaskExampleController());

  print('Starting a task that fails once but succeeds on retry...');
  int attempts = 0;
  final result = await taskController.tasksEngine.schedule<String>(
    () async {
      attempts++;
      if (attempts == 1) {
        print('  Attempt 1: Throwing temporary error...');
        throw Exception('Temporary network error');
      }
      return 'Success after $attempts attempts!';
    },
    retries: 2,
    retryDelay: const Duration(milliseconds: 500),
  );
  print('Result: $result');

  print('\n2. SelectionMixin Demo - Multi-selection');
  final selectionController =
      scope.put(() => SelectionExampleController<String>());

  selectionController.select('Apple');
  selectionController.select('Banana');
  print('Selected items: ${selectionController.selectedItems.value}');
  print('Is "Apple" selected? ${selectionController.isSelected('Apple')}');

  selectionController.toggle('Banana');
  print('After toggling "Banana": ${selectionController.selectedItems.value}');

  print('\n3. TimeMixin Demo - Debouncing');
  final timeController = scope.put(() => TimeExampleController());

  print(
      'Triggering multiple debounced calls (only the last one should run)...');
  for (int i = 1; i <= 3; i++) {
    timeController.debounce('search', const Duration(milliseconds: 300), () {
      print('  Debounced search executed (last call wins)');
    });
  }
  await Future.delayed(const Duration(milliseconds: 500));

  print('\n4. ExecutionLoopMixin Demo - Periodic Loops');
  final loopController = scope.put(() => LoopExampleController());

  print('Starting a background loop (ticking every 200ms)...');
  loopController.loopEngine.startLoop('ticker', () async {
    print(
        '  Tick! (Status: ${loopController.loopEngine.getServiceStatus('ticker')?.value})');
  }, delay: const Duration(milliseconds: 200));

  await Future.delayed(const Duration(milliseconds: 700));
  print('Stopping background loop.');
  loopController.loopEngine.stopService('ticker');

  print('\n--- Example Complete ---');
  scope.dispose();
}
