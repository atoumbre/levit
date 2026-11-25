import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';
import 'package:levit_dart/tasks.dart';

// Test controller to verify own integration
class TestController extends LevitController {
  bool isClosedCalled = false;
  late final value = own(0.lx);

  @override
  Future<void> onClose() async {
    isClosedCalled = true;
    await super.onClose();
  }
}

// Test custom disposable to verify LevitAutoDispose integration
class TestDisposable implements LevitDisposable {
  bool isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
  }
}

void main() {
  test('LevitStore should own LevitTaskEngine', () async {
    final tasksState = LevitStore((ref) {
      final engine = ref.own(LevitTaskEngine(maxConcurrent: 2));
      return engine;
    });

    final scope = LevitScope.root('task_scope');
    final engine = tasksState.findIn(scope);

    // Run a task to make sure it works
    final result = await engine.schedule(
      (_) async => 'success',
      id: 'task1',
      priority: LevitTaskPriority.normal,
      retryPolicy: LevitRetryPolicy(
        shouldRetry: (error, stack) => true,
        maxRetries: 0,
        initialDelay: const Duration(milliseconds: 500),
        maxDelay: const Duration(seconds: 30),
        jitter: 0,
      ),
      onError: (e, s) {},
    );

    expect(result, equals('success'));

    // Dispose scope
    await scope.dispose();
  });

  test('LevitStore should own LevitController', () async {
    late TestController capturedController;

    final controllerState = LevitStore((ref) {
      final controller = ref.own(TestController());
      capturedController = controller;
      // Initialize manually since it's not being put in scope as a controller
      controller.onInit();
      return controller;
    });

    final scope = LevitScope.root('controller_scope');
    final controller = controllerState.findIn(scope);

    expect(controller, isA<TestController>());
    expect(controller.isClosedCalled, isFalse);
    expect(controller.value.value, equals(0));

    // Dispose scope which disposes state which disposes controller
    await scope.dispose();

    expect(capturedController.isClosedCalled, isTrue);
  });

  test('LevitStore should own custom LevitAutoDispose object', () async {
    late TestDisposable capturedDisposable;

    final disposableState = LevitStore((ref) {
      final disposable = ref.own(TestDisposable());
      capturedDisposable = disposable;
      return disposable;
    });

    final scope = LevitScope.root('disposable_scope');
    disposableState.findIn(scope);

    expect(capturedDisposable.isDisposed, isFalse);

    // Dispose scope
    await scope.dispose();

    expect(capturedDisposable.isDisposed, isTrue);
  });
}
