# Structured Tasks, Async Maps & Loops (Levit 0.1.0)

## Everyday Barrel vs. `tasks.dart`

The default kit barrel (`package:levit_flutter/levit_flutter.dart` or `package:levit/levit.dart`) exposes everyday task types:
- `LevitTasksMixin` & `LevitReactiveTasksMixin`
- `LevitTaskConflictPolicy` (`reject`, `join`, `drop`, `restart`, `enqueue`, `coalesceLatest`)
- `LevitTaskContext`, `LevitRetryPolicy`, `LevitTaskPriority`, `LevitAsyncMap`
- `LevitTimeMixin`, `LevitSelectionMixin`, `LevitLoopMixin`

Import the opt-in barrel for advanced orchestration (engine internals, task groups, outcomes, caching, middleware, trackers):

```dart
import 'package:levit_flutter/tasks.dart'; // or package:levit/tasks.dart
```

## Controller Task Execution

```dart
class SaveController extends LevitController with LevitReactiveTasksMixin {
  Future<void> saveDocument(Document doc) async {
    await runTask<void>(
      'save',
      (ctx) async {
        ctx.throwIfCancelled();
        ctx.reportProgress(0.5, message: 'Uploading...');
        await api.save(doc);
      },
      policy: LevitTaskConflictPolicy.coalesceLatest,
      retryPolicy: LevitRetryPolicy(
        maxAttempts: 3,
        shouldRetry: (error, _) => error is NetworkException,
      ),
    );
  }
}
```

### 0.1.0 Task Contracts

- **Typed outcomes & exceptions:** Task futures return `Future<T>`. Cancellation, dropping, and supersession throw typed task exceptions (or inspect `execution.outcome`). Never interpret `null` as cancellation.
- **Retries:** Configure retries explicitly via `LevitRetryPolicy` with an application error classifier and capped delays; cancellation/deadline exceptions bypass retry.
- **Concurrency & limits:** Controller mixins default to `maxConcurrentTasks = 8` and pending capacity `256`.
- **Workflow groups:** Use `controller.taskGroup.runGroup(...)` for coordinated child tasks (cancels siblings on error by default). Group deadlines include queue time.
- **Isolates:** Use `scheduleIsolate`, `submitIsolate`, or `runIsolateTask` for CPU-bound work; cancellation reasons propagate into isolates and cleanup waits for isolate exit.
- **Disposal:** Task mixins drain active runners in `onBeforeClose()` before owned resources close. Always delegate `await super.onBeforeClose()`.

## Keyed Async Loading (`LevitAsyncMap`)

```dart
class CatalogController extends LevitController with LevitTasksMixin {
  late final items = own(
    LevitAsyncMap<String, Product>(
      loader: (id, ctx) => api.fetchProduct(id),
    ),
  );

  Future<Product> ensureLoaded(String id) => items.fetch(id);
  Future<Product> reload(String id) => items.refresh(id);
}

// In Flutter widget:
LStatusBuilder<Product>(
  controller.items.entry(productId),
  onWaiting: (status) => const CircularProgressIndicator(),
  onError: (status) => Text('${status.error}'),
  onSuccess: (product) => Text(product.title),
)
```

## Managed Loops (`LevitLoopMixin`)

Use `LevitLoopMixin` for periodic/background loops tied to controller lifetime. To replace an existing loop ID, always `await stopService(id)` before re-registering.
