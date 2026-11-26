# Migrating to Levit

This guide maps concepts and everyday patterns from **Riverpod**, **Bloc / Cubit**,
and **GetX** onto Levit's ownership-first runtime.

If you are brand new to Levit, read [Getting Started](ONBOARDING.md) alongside
this guide. For deeper architectural rationale, see [Why Levit](WHY_LEVIT.md).

---

## 1. Concept Mapping Cheat Sheet

| Concern | Riverpod | Bloc / Cubit | GetX | Levit |
| :--- | :--- | :--- | :--- | :--- |
| Mutable reactive value | `Notifier` / `StateProvider` | `Cubit<T>` | `0.obs` (`Rx<T>`) | `0.lx` (`LxVar<T>`) |
| Derived / computed state | `Provider((ref) => ...)` | `BlocSelector` / getter | `Obx` / getter | `computed(() => ...)` / `LxComputed` |
| Async derived state | `FutureProvider` / `AsyncNotifier` | `Bloc` + loading/error state | `StateMixin` / manual `Rx` | `asyncComputed(() async => ...)` + `await computed.wait` |
| Stream state | `StreamProvider` | `emit.forEach(...)` | `Rx.bindStream` | `LxStream` / `LxStream.defer` |
| Keyed cached queries | `FutureProvider.family.autoDispose` | Custom repository cache | Manual map of controllers | `LevitAsyncMap<K, V>` |
| Business logic owner | `Notifier` / `AsyncNotifier` | `Bloc` / `Cubit` | `GetxController` | `LevitController` |
| Lightweight recipe / token | `Provider<T>` | `RepositoryProvider<T>` | `Get.lazyPut` | `LevitStore<T>` / `LevitAsyncStore<T>` |
| Subtree / feature scope | `ProviderScope` | `MultiBlocProvider` | `Bindings` + `GetPage` | `LScope` / `LAsyncScope` / `LScopedView` |
| Route-bound scope | `autoDispose` | Route-local `BlocProvider` | `GetPage(binding:)` | `LRouteScope` / `LAsyncRouteScope` |
| Resolve in widget | `ref.read` / `ref.watch` | `context.read<T>()` | `Get.find<T>()` | `context.levit.find<T>()` |
| Focused widget rebuild | `Consumer` / `ref.watch(p.select(...))` | `BlocBuilder` / `BlocSelector` | `Obx(() => ...)` | `LWatch`, `LBuilder`, `LSelectorBuilder` |
| Async UI states | `asyncValue.when(...)` | `switch (state)` in `BlocBuilder` | `controller.obx(...)` | `status.when(...)` / `LStatusBuilder` |
| Side effects / reactions | `ref.listen(...)` | `BlocListener` | `ever` / `debounce` / `interval` | `LxWorker(...)`, `LevitTimeMixin` |
| Concurrency & double-taps | Manual / custom | `bloc_concurrency` transformers | Manual | `LevitTasksMixin` (`runLatest`, `runDrop`, `runQueued`, ...) |
| Scoped dialogs / sheets | Works via root `ProviderScope` | `BlocProvider.value` manually | `Get.dialog` (`GetMaterialApp`) | `showLevitDialog` / `showLevitModalBottomSheet` |
| Test overrides & cleanup | `ProviderContainer(overrides:)` | Mock `Bloc` / `bloc_test` | `Get.testMode` / `Get.reset()` | `LevitTestScope(overrides:)` + `addTearDown(harness.close)` |
| Diagnostics & tooling | `ProviderObserver` + `riverpod_lint` | `BlocObserver` + `bloc_lint` | `Get.log` | `levit_monitor`, `levit_lints`, `levit_devtools`, `levit_mcp` |

---

## 2. Coming from Riverpod

### Mental Model Shift
Riverpod models your app as a **graph of top-level providers** managed by a
`ProviderContainer`, where lifetimes are mostly implicit (`autoDispose` when the
last widget stops watching).

Levit flips that axis: **scopes own lifecycles explicitly** (`LScope`,
`LAsyncScope`, `LRouteScope`, `LScopedView`), controllers own their state and
async work (`LevitController`), and tearing down a scope deterministically
cancels tasks and awaits cleanup in reverse ownership order (`LIFO`). No
`build_runner` code generation is required.

### Async State & Refreshing

**Riverpod:**
```dart
final queryProvider = StateProvider<String>((ref) => '');

final resultsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final query = ref.watch(queryProvider);
  final repo = ref.watch(catalogRepoProvider);
  return repo.search(query);
});

class ResultsView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(resultsProvider);
    return results.when(
      loading: () => const CircularProgressIndicator(),
      error: (err, _) => Text('Error: $err'),
      data: (items) => ProductList(items: items),
    );
  }
}
```

**Levit:**
```dart
class CatalogController extends LevitController {
  CatalogController(this.repo);
  final CatalogRepository repo;

  final query = ''.lx;
  late final results = asyncComputed(() => repo.search(query()));

  void setQuery(String value) => query.value = value;
}

class ResultsView extends StatelessWidget {
  const ResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.levit.find<CatalogController>();
    return LWatch(
      () => controller.results.when(
        onWaiting: () => const CircularProgressIndicator(),
        onError: (err, _) => Text('Error: $err'),
        onSuccess: (items) => ProductList(items: items),
      ),
    );
  }
}
```
*(Need stale-while-revalidate UI that keeps previous items visible while refreshing? Use `LStatusBuilder` and check `status.hasLastValue`.)*

- **Awaiting a computed value in logic/tests:** Replace `await ref.read(resultsProvider.future)` with `await controller.results.wait`.
- **Keyed `.family.autoDispose` caching:** Use [`LevitAsyncMap`](ADVANCED.md#2-caching-queries-refreshing-data-and-reconnecting-streams) for per-key caching, deduplication, stale-while-revalidate, and automatic unused-key eviction.

### Scoped Overrides & Testing

**Riverpod:**
```dart
final container = ProviderContainer(
  overrides: [counterProvider.overrideWith((ref) => 10)],
);
addTearDown(container.dispose);
```

**Levit:**
```dart
final counterStore = LevitStore((ref) => ref.own(0.lx));

final harness = LevitTestScope(
  overrides: [counterStore.overrideWith((ref) => ref.own(10.lx))],
);
addTearDown(harness.close);
```

### Riverpod Gotchas to Watch For
- **Fine-grained mutation vs. whole-state copying:** In Levit, reactive fields (`count.value++`, `LxList.add(...)`, `map.entry(key)`) notify only their direct readers—you do not need `copyWith` on a monolithic state class just to update one counter.
- **`LevitStore` inherits by default:** Reading a `LevitStore` in a child scope reuses an ancestor instance unless overridden or resolved with `localOnly: true`.
- **Explicit disposal of non-reactives:** Always wrap `TextEditingController`, `FocusNode`, `StreamSubscription`, `Timer`, or `LevitAsyncMap` in `own(...)`. Flutter `ChangeNotifier` controllers dispose automatically with `own(TextEditingController())` (pass `dispose:` for other third-party objects).

---

## 3. Coming from Bloc / Cubit

### Mental Model Shift
Bloc centers on **coarse-grained immutable state objects**, explicit `Event`
classes, and `Stream` transformers (`bloc_concurrency`). That gives strong
predictability, at the cost of boilerplate and coarser rebuild boundaries unless
you add `BlocSelector` everywhere.

Levit keeps the same separation between UI and logic (`LevitController`), replaces
coarse event/state boilerplate with fine-grained reactives (`.lx`, `LxComputed`),
and ships first-class **structured concurrency and conflict policies**
(`LevitTasksMixin`, `LevitTaskGroup`) that drain automatically when a screen
closes.

### State, Selectors & Scoped Providers

**Bloc:**
```dart
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CounterCubit(),
      child: Builder(
        builder: (context) => Scaffold(
          body: BlocBuilder<CounterCubit, int>(
            builder: (_, count) => Text('$count'),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.read<CounterCubit>().increment(),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}
```

**Levit:**
```dart
class CounterController extends LevitController {
  final count = 0.lx;
  void increment() => count.value++;
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LScopedView.put(
      CounterController.new,
      autoWatch: false,
      builder: (context, controller) => Scaffold(
        body: LWatch(() => Text('${controller.count()}')),
        floatingActionButton: FloatingActionButton(
          onPressed: controller.increment,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

### Concurrency (`bloc_concurrency` → `LevitTasksMixin`)

| `bloc_concurrency` | Levit helper | Policy (`LevitTaskConflictPolicy`) | Behavior |
| :--- | :--- | :--- | :--- |
| `droppable()` | `runDrop('id', ...)` | `drop` | Ignores overlapping submissions (e.g. double-taps). |
| `restartable()` | `runLatest('id', ...)` | `restart` | Cancels in-flight task cooperatively and starts the new one. |
| `sequential()` | `runQueued('id', ...)` | `enqueue` | Runs submissions strictly in FIFO order. |
| *(manual)* | `runCoalesceLatest('id', ...)` | `coalesceLatest` | Finishes current run, then runs once more with the latest input. |
| *(manual)* | `runJoin('id', ...)` | `join` | Shares the in-flight `Future` result across concurrent callers. |
| *(manual)* | `runTask(..., id: 'id')` | `reject` *(default)* | Rejects overlapping calls with `LevitTaskConflictException`. |

### Side Effects (`BlocListener` → `LxWorker`)
Instead of `BlocListener` widgets scattered across the tree, register reactive
reactions in the controller's `onInit()` with `LxWorker`—because `LxWorker` is
an `LxReactive`, auto-linking closes it automatically when the controller
disposes (wrap in `own(LxWorker(...))` if you create one later outside
constructor/`onInit()`, or without auto-linking):

```dart
@override
void onInit() {
  super.onInit();
  LxWorker(selectedWorkspaceId, (_) async => reloadWorkspace());
}
```

### Bloc Gotchas to Watch For
- **Dialogs & bottom sheets:** Instead of manually wrapping dialogs with `BlocProvider.value(value: context.read<MyBloc>(), child: ...)`, call `showLevitDialog` or `showLevitModalBottomSheet`—they automatically capture the caller's `LScope`.
- **Immutable union states still work:** If a workflow truly benefits from a sealed state machine, hold it in a single `LxVar<CheckoutState>` and observe it with `LBuilder` or `LWatch`.

---

## 4. Coming from GetX

### Mental Model Shift
Levit feels immediately familiar to GetX developers (`.lx` ≈ `.obs`, `LWatch` ≈
`Obx`, `LevitController` ≈ `GetxController`), but intentionally fixes GetX's
hardest production failure modes:

1. **No global singleton sprawl:** Feature controllers live inside widget-tree `LScope` / `LScopedView` / `LRouteScope` boundaries, not a flat global map.
2. **Awaited, deterministic LIFO teardown:** Closing a scope cancels tracked tasks, runs `onBeforeClose()`, drains in-flight work, closes owned resources in reverse order, and surfaces teardown errors instead of swallowing them.
3. **Standard Flutter navigation & overlays:** Levit does **not** replace `MaterialApp`, `Navigator`, `GoRouter`, or HTTP clients—it integrates directly with standard Flutter APIs.

### Controller & Reactive UI

**GetX:**
```dart
class ProfileController extends GetxController {
  final name = 'Ada'.obs;
  void rename(String next) => name.value = next;
}

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Get.put(ProfileController());
    return Scaffold(
      body: Obx(() => Text(c.name.value)),
    );
  }
}
```

**Levit:**
```dart
class ProfileController extends LevitController {
  final name = 'Ada'.lx;
  void rename(String next) => name.value = next;
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LScopedView.put(
      ProfileController.new,
      autoWatch: false,
      builder: (context, c) => Scaffold(
        body: LWatch(() => Text(c.name())),
      ),
    );
  }
}
```

### Workers & Timers (`ever` / `debounce` → `LxWorker` / `LevitTimeMixin`)
- `ever(rx, cb)` → `LxWorker(rx, cb)` (auto-linked during constructor/`onInit()`; wrap in `own(...)` if created later or without auto-linking)
- `debounce(rx, cb, time: d)` → mix in `LevitTimeMixin` and call `debounce('key', d, () => ...)` (auto-cancelled on controller close)
- `Get.dialog(...)` / `Get.bottomSheet(...)` → `showLevitDialog(...)` / `showLevitModalBottomSheet(...)`

### GetX Gotchas to Watch For
- **Never call `Levit.find<T>()` inside widgets:** Always resolve via `context.levit.find<T>()` so lookups respect nested `LScope` trees (`levit_lints/avoid_global_levit_in_widgets` catches this statically).
- **Always `await` scope disposal & `super.onClose()`:** In pure Dart and tests, `await scope.dispose()` and `await super.onClose()` ensure async cleanup actually finishes (`levit_lints/await_levit_lifecycle` and `discarded_levit_future` enforce this).
- **No pre-constructed `put`:** Pass builders (`scope.put(() => MyController())`), not already-constructed instances (`scope.put(() => existing)`), so auto-linking captures constructor reactives.

---

## 5. Incremental Adoption (No Big-Bang Rewrite)

You do not need to rewrite an existing Riverpod, Bloc, Provider, or GetX app to
adopt Levit:

1. **Start at a single feature or screen boundary:** Wrap one new screen in `LScopedView.put` (or a multi-screen flow in `LScope`). Mounting `LScope` in Flutter enables auto-linking automatically unless you explicitly called `Levit.disableAutoLinking()`.
2. **Bridge existing services in:** Pass existing repositories or clients from `Provider` / `GetIt` / `Riverpod` into your `LScope` `configure` callback via `scope.put(() => existingRepo)` (or `Levit.bindExisting` for interface aliases).
3. **Bridge reactive values back out to legacy widgets:** Use `source.asValueListenable()` (owned via `own(...)` on your controller) whenever a third-party widget or legacy subtree expects a `ValueListenable<T>`.
4. **Enable `levit_lints` early:** Adding [`levit_lints`](../packages/tools/levit_lints) to your root `analysis_options.yaml` catches lifecycle and scoping mistakes across mixed codebases immediately.
