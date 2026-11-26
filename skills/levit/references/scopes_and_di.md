# Scopes, Dependency Injection & Stores (Levit 0.1.0)

## Scope Registration & Resolution

Construct dependencies inside registration builders so scopes own construction, initialization, and disposal.

```dart
// Root or current active scope (pure Dart / app bootstrap)
Levit.put(() => ApiClient());
Levit.lazyPut(() => AuthService());
Levit.lazyPutAsync(() async => await Database.open());
Levit.bindExisting<AuthPort, AuthService>(); // non-owning alias

// Resolve in pure Dart
final api = Levit.find<ApiClient>();
final db = await Levit.findAsync<Database>();

// Resolve in Flutter widgets (always respects nearest LScope)
final api = context.levit.find<ApiClient>();
final maybeAuth = context.levit.findOrNull<AuthService>();
```

### Lifetime & Disposal Rules

- **Scope lookup order:** Current scope first, then ancestors. A child scope borrows ancestor instances and never disposes them.
- **`permanent: true`:** Survives a regular `reset()`, but `scope.dispose()` always force-clears all owned registrations.
- **Factories (`isFactory: true`):** Non-permanent by default. Disposable factory instances are owned by the registering scope; release early with `await scope.releaseFactoryInstance(instance)`.
- **Replacement:** Always `await scope.delete<T>()` before re-registering an already-instantiated key.
- **Optional lookup:** `findOrNull<T>()` returns `null` only when absent; construction/type errors propagate.
- **External async init:** Wrap external setup in `scope.runInitialization(() async { ... })` so disposal waits cleanly and self-disposal is prevented.

## Flutter Scope Widgets

- **`LScopedView<C>.put(() => C(), builder: ...)`**: Owns a child scope and one primary controller.
- **`LScope` / `LAsyncScope`**: Provides a scope to a subtree (`dependency` / `onConfigure`).
- **`LView<T>` / `LAsyncView<T>`**: Consumes an existing dependency from the nearest scope. Pass captured inputs in `args: [id]` — a new resolver closure alone does not trigger re-resolution.
- **`LRouteScope` / `LAsyncRouteScope`**: Binds scope lifetime to route identity (works with Navigator and GoRouter).
- **Overlays:** Use `showLevitDialog` / `showLevitModalBottomSheet` (from `levit_flutter`) or `LScope.capture(context, child: ...)` so dialogs/sheets inherit the caller's scope.
- **Scope replacement:** Changing ownership args drains and disposes the previous scope generation before creating the next. `LevitScopeLifecycleController` exposes loading/failure/retry state.

## Portable State Recipes (`LevitStore`)

Keep store definitions stable (typically top-level `final`). Identity is definition object + optional variant tag.

```dart
final counterStore = LevitStore<LxVar<int>>(
  (ref) => ref.own(0.lx.named('counter')),
);

// Flutter widget resolution (inherits ancestor instance by default)
final counter = context.levit.findStore(counterStore);

// Force a local instance in the current scope
final localCounter = context.levit.findStore(counterStore, localOnly: true);

// Pure Dart scope resolution
final scopedCounter = counterStore.findIn(scope);

// Async store
final profileStore = LevitAsyncStore<UserProfile>(
  (ref) async => await ref.find<UserApi>().loadProfile(),
);
final profile = await context.levit.findAsyncStore(profileStore);
```

### Overrides (Testing & Feature Customization)

Install typed overrides via `scope.applyOverrides(...)` before first local resolution:

```dart
scope.applyOverrides([
  counterStore.overrideWith((ref) => ref.own(99.lx)),
]);
```

## Controller Ownership

```dart
class SearchController extends LevitController {
  final query = ''.lx.named('query');
  late final TextEditingController textController;

  @override
  void onInit() {
    super.onInit();
    own(query);
    textController = own(
      TextEditingController(),
      dispose: (c) => c.dispose(),
    );
    own(LxWorker(query, (q) async => await runSearch(q)));
  }

  @override
  Future<void> onBeforeClose() async {
    await super.onBeforeClose();
  }

  @override
  Future<void> onClose() async {
    await super.onClose();
  }
}
```

- `own(resource)` has built-in adapters for Levit reactives, scopes, disposables, `StreamSubscription`, `Timer`, `Sink`, and cleanup functions.
- Unknown resource types require an explicit `dispose:` callback (`own(res, dispose: (r) => r.dispose())`).
- Cleanup runs LIFO, awaited, and idempotent. Disposal failures aggregate into `LevitDisposalException`.
