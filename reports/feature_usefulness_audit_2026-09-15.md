# Levit feature usefulness audit

> Scope update during 0.1.0 preparation: persistence and its codec/storage/task-cache/
> restoration integrations moved to the [ecosystem roadmap](ecosystem_roadmap.md).
> The [revised release plan](release_0.1.0_plan.md) retains native ValueListenable
> interoperability and countdown correctness in M7. Findings below are historical.

Date: 2026-09-15  
Scope: current working tree on commit `539f130`, including uncommitted 0.0.12 changes.  
Method: independent inventory of public libraries, implementation inspection, examples, targeted existing tests, and new behavioral probes. The pre-existing `reports/feature_set_audit.md` was neither used as an input nor overwritten.

## Executive assessment

**Levit has a useful core: scoped dependencies, resource ownership, derived state, and Flutter rebuild boundaries work well as one model. Its best next investment is making that model dependable across every asynchronous lifetime.**

The strongest audience is a Dart/Flutter team managing long-lived connections, feature sessions, editors, nested routes, and shared domain logic. Small applications with a few independent values gain less from the additional concepts. This is a product judgment based on the available implementation, not a claim about measured adoption.

Three conclusions drive this audit:

1. **Protect the ownership/reactivity core.** Scopes, controllers, non-controller owners, computed values, focused widgets, async status, and the task engine have distinct jobs. Removing these to make the API smaller would remove useful capability.
2. **Repair lifecycle and identity gaps before adding breadth.** Probes reproduced incorrect tagged-store reuse, obsolete async initialization disposing its replacement, unfinished work surviving owner disposal, and family invalidation leaving observers stale.
3. **Deprecate misleading or redundant surfaces selectively.** The strongest candidates are `.toBuilder`, the current history middleware as a general-purpose undo facility, and exact naming aliases. Selection, time, and keep-alive helpers deserve lower prominence rather than an urgent breaking removal.

### Most important findings

| Priority | Finding | Consequence |
| --- | --- | --- |
| P1 | An obsolete `LAsyncScope` initialization error disposes the current replacement scope. | A route or argument change can destroy healthy new dependencies. |
| P1 | Different stores of the same result type share an instance when passed the same explicit tag. | Independent state recipes silently return each other's data. |
| P1 | Owned workers and loops do not drain running callbacks before owner cleanup completes. Pending async singleton construction also outlives `scope.dispose()`. | Awaiting disposal is not a uniform guarantee that owned asynchronous work has ended. |
| P1 for undo-dependent apps | History can report successful undo without reverting an in-place collection mutation. Batched undo exposes intermediate states. | The advertised operation can fail at its actual user-facing purpose. |
| P2 | `LxFamily.invalidate` closes the current entry without rebinding existing observers. | Refreshing cached data can leave a view/computed value permanently stale until another trigger rebuilds it. |

P1 means address before promoting the affected capability as dependable. P2 means a material product gap; it does not imply every application is affected.

## Evaluation framework

Usefulness is assessed for Levit's intended ownership-heavy applications:

- **5 — Essential:** central to the framework's value.
- **4 — Strong:** solves a frequent, meaningful problem.
- **3 — Situational:** worthwhile for a clear subset of applications.
- **2 — Marginal:** small convenience or significant overlap.
- **1 — Retire current form:** the existing surface is misleading or fails its intended abstraction.

The score measures utility, not implementation quality. A feature can score 5 and still need a serious fix. `Keep` means continue supporting it; `Improve` means invest in a concrete deficiency; `Demote` means keep it available with less onboarding prominence; `Deprecate` means provide a migration and phase out the named surface.

## Feature-by-feature assessment

### 1. Scopes, registration, and ownership

Implementation references: [scope runtime](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_scope/lib/src/core.dart), [Levit facade](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_dart_core/lib/src/core.dart), [owners/controllers](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_dart_core/lib/src/controller.dart), [auto-linking](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_dart_core/lib/src/auto_linking.dart), [stores](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_dart_core/lib/src/store.dart).

| Feature | Value | Decision | Assessment |
| --- | --- | --- | --- |
| Root/child scopes and ancestor resolution | 5 | Keep; improve lifetime contract | Feature/session/request boundaries and local overrides are foundational. Manual children are lookup descendants, not automatically owned descendants; parent disposal does not close them. |
| Explicit scope access and zone-bound `run`/`runInScope` | 5 | Keep | Essential for pure Dart, request handling, isolated tests, and code shared with Flutter. `runInScope` provides a useful awaited boundary for registered resources. |
| Eager `put` and lazy `lazyPut` | 5 | Keep | Immediate setup and on-demand setup are distinct needs. Builder-based registration supports initialization capture. |
| `lazyPutAsync` and `findAsync` | 4 | Improve | Valuable for connections/configuration and deduplicated initialization. Align pending-singleton teardown with the already stronger factory/task contracts. |
| Per-resolution factories | 3 | Improve | Useful for scope-owned instances with independent state. Disposable results accumulate under the registering scope; a root factory can retain every result until removal. Add explicit early-release ownership or teach shorter factory scopes. |
| Type/tag registration keys | 4 | Keep | Multiple implementations or instances of one type are legitimate. Avoid extending string tags into a second configuration language. Store identity needs a separate fix. |
| `permanent` | 2 | Demote; decouple from factories | Surviving a non-forced reset is useful occasionally. It does not extend widget/scope lifetime, and `isFactory` silently forces it on. Construction strategy should not determine reset survival. |
| `bindExisting` aliases | 4 | Keep | Multiple interface ports can resolve one owned singleton without duplicate cleanup. Local, non-owning aliases are a good, deliberately limited feature. |
| Probes and removal: `findOrNull`, registration checks, `delete`, `reset` | 4 | Keep; tighten error semantics | Useful integration and test primitives. Flutter `findOrNull*` catches all exceptions, so initialization/type errors can look like missing dependencies. Optional lookup should distinguish those cases. |
| `LevitController` lifecycle | 5 | Keep; improve safety | A coherent unit for feature logic and cleanup. Required super calls and async hook ordering need tooling, not repeated reminders alone. |
| `LevitResourceOwner`, `LevitResourceOwnership`, `own` | 5 | Keep | Extends the ownership model to repositories/services without forcing controller inheritance. Awaited, idempotent, LIFO cleanup and aggregated failures are substantive value. |
| `autoDispose` alias | 3 | Keep compatibility; prefer `own` in new material | Widely used by this checkout's examples and still understandable. An immediate removal would cost more than it saves. Teach one preferred ownership verb. |
| Duck-typed cleanup of arbitrary objects | 3 | Improve | Convenient for Flutter and third-party resources. Offer an explicit typed disposer adapter when cleanup cannot be safely inferred; avoid silently accepting unsupported resources. |
| Automatic reactive ownership capture | 4 | Improve | Reduces field-registration boilerplate substantially. Its bootstrap switch and allocation-context boundaries are easy to miss. Prefer explicit configuration and diagnostics for uncaptured resources; keep monitoring independent. |
| `runGuardedAsync` | 3 | Keep; clarify naming | Useful for discarding a result after closure. It cannot cancel an HTTP call or prevent writes inside the supplied callback. Rename/deprecate the misleading `cancelOnClose` parameter in favor of a result-discard name. |
| `LevitStore`, `LevitAsyncStore`, `LevitRef` | 4 | Improve | Portable state recipes are a useful alternative to controller classes. They currently build once; they are not a dependency-invalidating provider graph. Fix key identity and add typed overrides before expanding store APIs. |
| Store inheritance and `localOnly` | 4 | Keep | Shared ancestor state and independently owned local state are both necessary. Preserve the explicit choice; a newly created widget scope alone does not guarantee a new store instance. |

### 2. Reactive state

Implementation references: [base types](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/base_types.dart), [reactive core](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/core.dart), [collections](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/collections.dart), [computed values](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/computed.dart), [async wrappers](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/async_types.dart), [status](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/async_status.dart), [workers](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/workers.dart), [families](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/family.dart).

| Feature | Value | Decision | Assessment |
| --- | --- | --- | --- |
| `LxVar`, `.lx`, `.value`, read-only call syntax | 5 | Keep | A small, useful mutation/read model. The 0.0.12 separation of calls for reading and setters for writing is worth preserving. |
| Custom equality, explicit refresh/mutate/update | 4 | Keep | Supports immutable records and external mutable models. Explain that in-place mutations need explicit notification and cannot automatically provide historical snapshots. |
| Specialized bool/numeric types and arithmetic helpers | 2 | Demote | Toggling is convenient; a large arithmetic vocabulary adds little beyond `value` operations. Preserve `.lx` return-type compatibility. The implementation does not by itself substantiate the DartDoc's special “unboxed” performance claim. |
| `LxState`, reducer updates, `asReactive` | 3 | Improve | Useful for a controlled state API, but it does not freeze `T`. `LxReactive` still exposes `close`, `refresh`, and metadata mutation; provide a genuinely observation-only interface when authority separation matters. |
| `LxList`, `LxMap`, `LxSet` | 5 | Keep | Familiar collections remove substantial boilerplate. Tracking is at collection level, not automatically per element/key; nested plain objects do not become deeply reactive. |
| Synchronous `LxComputed`, dynamic dependency tracking | 5 | Keep | Shared derived state is a core feature. Constructor evaluation, later laziness, equality, and observer activation should be documented precisely. |
| `select` | 4 | Keep | An explicit selection can suppress irrelevant output updates. Useful with large state objects and whole-collection notification. |
| `staticDeps`, `eager`, `.lxStatic` | 2–3 | Demote to advanced tuning | Static graphs are useful when dependency membership truly cannot change. Conditional reads make them hazardous. Keep them only with measured workloads and explicit constraints. |
| Function `.lx` and deferred computed sugar | 2–3 | Keep, low prominence | Convenient notation around existing computed semantics. Do not invent additional synonyms or treat microtask deferral as CPU offloading. |
| Async computed values and `latest`/`exhaustLatest` | 4 | Improve | Useful for query-dependent data and coalesced refreshes. Stale publication suppression and overlap control are real value; physical cancellation, cleanup completion, and retry remain separate concerns. |
| `LxFuture` | 4 | Keep | Tracks an explicitly started operation, including restart and stale completion suppression. Distinct from dependency-driven async computed values. |
| `LxStream`, lazy/deferred binding, restart, completion policy | 4 | Keep | Important for subscriptions and reconnectable data. `retain` has a real purpose. Make single-subscription/deferred-source behavior prominent in docs. |
| Stream interop, `bind`/`unbind`, transforms | 4 | Keep | Enables gradual adoption alongside Dart streams and other libraries. Prefer standard stream operators to growing a separate operator library. |
| `LxStatus` and stale-value retention | 5 | Improve ergonomics | Idle/waiting/success/error with prior data is useful across queries and commands. Preserve it; improve nullable-data presence semantics and refreshed/error rendering rather than adding another async-state hierarchy. |
| Status predicates, `requireValue`, `wait`, status listeners | 4 | Keep; prune aliases | Removes repetitive status branching. `computedValue` duplicates `requireValue`. Preserve the difference between terminal status observation and cancellation of the underlying operation. |
| `LxWorker` side effects | 5 | Improve urgently | The recommended reload/reaction primitive deserves owner-aware cancellation and awaited draining. `latest` permits overlapping side-effect callbacks; it cannot undo effects already performed by an older callback. |
| Worker transitions, distinct changes, debounce/throttle | 3–4 | Keep | Common glue for searches and reactions. Their reactive-source trigger differs from the imperative timers in `LevitTimeMixin`, so those are not exact duplicates. |
| Worker execution statistics | 3 | Make explicitly optional in normal use | Profiling counters/durations are useful, but monitoring defaults on and each worker itself exposes reactive statistics. Measure the cost and prefer a quiet default for unobserved diagnostics. |
| `batch` | 5 | Keep | Coalescing related updates is fundamental. Preserve deterministic propagation tests. |
| `batchAsync` | 3 | Keep as advanced | Context-local batching across awaits is useful occasionally. It shares values and flushes on errors; it is not isolation or rollback. Prefer a final synchronous batch for ordinary network-result application. |
| `LxFamily`, explicit eviction, inactivity grace | 4 | Improve urgently | A keyed resource cache is useful. Existing invalidation does not refresh subscribers, and the default retains entries until explicit removal. Add reactive invalidation semantics and bounded retention choices. |
| Names, owner IDs, sensitivity metadata | 4 | Keep | Makes runtime relationships inspectable and enables redaction. Labels support debugging; they should not substitute for identity or security boundaries. |

### 3. Flutter integration

Implementation references: [watch](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_flutter_core/lib/src/watch.dart), [builders](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_flutter_core/lib/src/builder.dart), [scope](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_flutter_core/lib/src/l_scope.dart), [async scope](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_flutter_core/lib/src/l_async_scope.dart), [views](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_flutter_core/lib/src/view.dart), [scoped views](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_flutter_core/lib/src/scoped_view.dart), [route scopes](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_flutter_core/lib/src/route_scope.dart), [context access](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_flutter_core/lib/src/levit_provider.dart), [overlays](/Users/atoumbre/SoftiLab/levit-svg/packages/kits/levit_flutter/lib/src/overlays.dart).

| Feature | Value | Decision | Assessment |
| --- | --- | --- | --- |
| `LWatch` | 5 | Keep | The central focused-rebuild primitive. Provides clear value with thin widgets and localized reactive reads. |
| `LBuilder` | 4 | Keep | An explicit source is simpler when the dependency is already known. It need not be removed just because `LWatch` can express similar UI. |
| `LSelectorBuilder` | 3 | Keep, secondary | Owns a widget-local derivation and avoids manually managing a computed lifetime. Shared derivations belong in controllers/stores. |
| `LStatusBuilder` | 4 | Improve | Good convenience for async UI. Waiting/error callbacks cannot directly receive retained data; add a status-aware builder or a clear retained-data option. |
| `LScope` and registration helpers | 5 | Keep; improve replacement/disposal | Maps dependencies onto subtree lifetime. Expose cleanup completion/error handling and an explicit policy for replacing a scope while old cleanup is pending. |
| `LAsyncScope` | 4 | Fix | A readiness gate is distinct from lazy async registration. Fix stale-generation error handling, then add deliberate retry/reset controls. |
| Consuming `LView` / `LAsyncView` | 4 | Keep | Resolve an existing dependency without taking ownership. Async resolution warrants its own readiness behavior. |
| Owning `LScopedView` / `LScopedAsyncView` | 4 | Keep | A useful shortcut for a controller and its lifetime boundary. Ownership is a meaningful distinction, not redundant naming. Keep factory and subclass styles without expanding the matrix further. |
| `autoWatch` and explicit `args` | 3–4 | Keep; improve discoverability | Stable resolver behavior is now explicit in 0.0.12. Changing closure identity alone does not refetch. Avoid a cosmetic `args`→`deps` migration unless it resolves a demonstrated usability problem. |
| `context.levit` | 5 | Keep; strengthen type safety | Correctly resolves through widget scope. The `dynamic key` store path loses type safety and does not offer the same explicit local-store choice as `.store(..., localOnly: ...)` constructors. Add typed store accessors. |
| `LRouteScope`, `LAsyncRouteScope`, route visibility | 4 | Keep | Route identity and covered/current state are valuable for retained screens. These are lifecycle integrations, not a reason to create a Levit router. |
| Scope capture and dialog/sheet helpers | 4 | Keep | Bridges real overlay ancestry gaps. Capturing a scope borrows it; it does not extend the source owner's lifetime. Document what happens when an overlay survives its originating page. |
| `LevitAppLifecycleMixin` | 3 | Keep as optional integration | Useful for connections and refresh policy. Application resume/pause is distinct from route visibility. |
| `LevitLoopExecutionLifecycleMixin` | 3 | Improve alongside loops | Pausing repetitive work in the background is valuable. Preserve user pause intent and distinguish requesting pause/stop from waiting for active work to finish. |
| `LKeepAlive` | 2–3 | Demote | A convenient wrapper around Flutter keep-alive mechanics. Small maintenance cost; no strong reason for urgent removal. It is a retention choice, not part of the state model. |
| `LWidgetMonitor` | 2 | Deprecate from the primary kit; offer a recipe | Reports mount/unmount only and contains no Levit ownership behavior. A small local `StatefulWidget` expresses this directly. It should not be presented as viewport visibility or reliable pagination machinery. |

### 4. Tasks and utility mixins

Implementation references: [task engine](/Users/atoumbre/SoftiLab/levit-svg/packages/kits/levit_dart/lib/src/utilities/levit_task_engine.dart), [task models/tracker/cache interfaces](/Users/atoumbre/SoftiLab/levit-svg/packages/kits/levit_dart/lib/src/utilities/task_engine_models.dart), [task mixins](/Users/atoumbre/SoftiLab/levit-svg/packages/kits/levit_dart/lib/src/mixins/tasks_mixin.dart), [cache](/Users/atoumbre/SoftiLab/levit-svg/packages/kits/levit_dart/lib/src/utilities/task_engine_cache.dart), [loops](/Users/atoumbre/SoftiLab/levit-svg/packages/kits/levit_dart/lib/src/utilities/levit_loop_engine.dart), [time](/Users/atoumbre/SoftiLab/levit-svg/packages/kits/levit_dart/lib/src/mixins/time_mixin.dart), [selection](/Users/atoumbre/SoftiLab/levit-svg/packages/kits/levit_dart/lib/src/mixins/selection_mixin.dart).

| Feature | Value | Decision | Assessment |
| --- | --- | --- | --- |
| `LevitTaskEngine`, bounded active concurrency | 4 | Keep | Useful for saves, uploads, sync, and CPU jobs. Owner shutdown already drains runners, a stronger contract worth extending elsewhere. |
| `reject`, `join`, `drop` conflict policies | 4 | Keep | Different answers to duplicate requests: reject misuse, share work, or ignore another trigger. Stable logical IDs must be taught. |
| `restart`, `enqueue`, `coalesceLatest` | 4 | Keep | Distinct needs for replacement, ordered writes, and a single latest trailing request. Coalescing is especially useful for refresh/save bursts; cancellation remains cooperative. |
| Priority queues and runtime concurrency configuration | 3 | Improve | Useful when interactive work competes with background work. Active concurrency is bounded, queue admission is not; sustained high-priority traffic can starve lower-priority work. |
| Retries and exponential backoff | 4 | Improve | Practical resilience support. Add a retry predicate, jitter, and deadline/budget integration so permanent failures and non-idempotent work are not retried indiscriminately. |
| Task context, progress, execution identity, cancellation | 5 | Keep; improve results | Connects async work to ownership and UI. Add a typed terminal result to distinguish successful `null`, cancellation, dropping, and supersession without correlating middleware events. |
| Engine-only `LevitTasksMixin` | 4 | Keep | A useful lighter choice for services without UI task state. Do not force every consumer to allocate reactive summaries. |
| `LevitReactiveTasksMixin`, task/category selectors, weighted progress, blocking state | 4 | Keep; improve examples | Solves real command-UI boilerplate and aggregate busy state. The current example apps do not exercise this important public feature directly. |
| `LevitTaskMiddleware` and `LevitTaskTracker` | 4 | Keep | Structured events support cross-controller task UI without a second execution engine. Explicit attachment and bounded terminal history are sound choices. |
| Task cache policy and pluggable storage | 3 | Keep narrow | TTL/result caching is useful for repeated reads. It does not provide query invalidation, optimistic mutations, persisted state restoration, or resumable jobs. Add namespaces/versioning and bounded default retention before calling it a general data cache. |
| Dedicated isolate tasks | 3–4 | Keep as advanced | Useful for genuinely expensive CPU work, with explicit message-safe input and progress/cancellation. Document platform and startup-cost limits; do not blur CPU parallelism with ordinary async I/O. |
| Loop engine and stoppable services | 3 | Redesign shutdown; retain use case | Sequential polling and service control are useful. The separate lifecycle is weaker than tasks: `stop()`/`dispose()` return before running bodies finish. Share task cancellation/drain mechanisms where practical. |
| Isolate loops | 2–3 | Freeze expansion pending lifecycle unification | Valid specialized use, but another substantial executor for a small audience. Keep compatibility while evaluating a repeated task/service abstraction with awaited completion. |
| `LevitTimeMixin`: debounce, throttle, intervals | 3 | Keep optional | Controller-owned imperative timers are useful and not identical to reactive-source workers. Centralize ownership and testability instead of growing more timer APIs. |
| `LxCountdown` | 2 | Demote or replace | A niche UI utility. It subtracts an interval per timer callback, so delayed ticks do not represent elapsed wall time accurately. Deadline-based calculation belongs in a reusable recipe or improved optional helper. |
| `LevitSelectionMixin` | 2 | Demote | Useful for simple single/multi-selection, but application identity, filtering, range selection, and disabled items remain domain decisions. `LxSet<ID>` plus controller methods often provides a clearer API. |

### 5. Middleware, diagnostics, packages, and tooling

Implementation references: [reactive middleware/history](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/middlewares.dart), [DI middleware](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_scope/lib/src/middleware.dart), [monitor facade](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_monitor/lib/src/core.dart), [monitor middleware](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_monitor/lib/src/middleware.dart), [snapshot model](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_monitor/lib/src/snapshot.dart), [lints](/Users/atoumbre/SoftiLab/levit-svg/packages/tools/levit_lints/lib/src/rules.dart), [package map](/Users/atoumbre/SoftiLab/levit-svg/README.md).

| Feature | Value | Decision | Assessment |
| --- | --- | --- | --- |
| DI/reactive interception middleware | 4 | Keep advanced | Enables diagnostics and extensions without embedding those concerns in business logic. Interceptors can change behavior; treat them differently from passive observers. |
| Token registration/replacement/removal | 4 | Keep | Important for hot reload, repeatable setup, and predictable feature teardown. One stable token per concern is a good canonical pattern. |
| Middleware bypass | 3 | Keep advanced | Useful for replay/import and avoiding feedback loops. Global bypass skips all concerns, so normal application workflows should prefer concern-specific suppression. |
| History middleware and undo/redo | 3 as a use case; 1 in current general form | Deprecate current general-purpose contract | Editors need undo, but this implementation cannot undo normal in-place collection changes and does not atomically restore a batch. Replace with opt-in immutable snapshots or domain commands with inverse operations. |
| Monitor events, graph/listener/owner metadata | 4 | Keep | Closely supports “what owns this?” and “what caused this update?” Runtime events alone are not yet a complete developer experience. |
| Filtering, sensitivity, obfuscation | 4 | Keep; verify end to end | Valuable for diagnostics involving real application data. Redaction is an export policy, not removal of raw in-process objects from retained events. Test the actual output transports and reconnect snapshots. |
| Console, file, WebSocket, multi/custom transports | 3–4 | Improve | Useful pluggable outputs. Add explicit delivery/drop semantics and awaited flush/shutdown; `detach()` currently discards the ability to await transport closure. |
| Shadow state and reconnect snapshots | 3 | Make selectable | Useful for inspectors. The middleware always constructs and maintains shadow state, including a default 10,000-event cache; the facade does not expose an opt-out for console-only usage. |
| Custom monitor events and application task bridge | 3–4 | Keep | An application adapter preserves package independence. A tested adapter example would reduce repeated manual event translation without coupling domain code to monitoring. |
| `levit_lints` | 5 potential; limited distribution | Prioritize | Four existing rules address real failures. Local checkout installation limits practical adoption. Publish/configure it and extend checks for awaited lifecycle delegation, wrong scope access, and uncaptured async work. |
| Core package separation | 4 | Keep | Standalone scope/reactive use and optional diagnostics are legitimate boundaries. Source package count alone is not a reason to merge everything. |
| `levit` and `levit_flutter` entry kits | 4 | Keep | Two clearly recommended imports simplify onboarding. `levit` is an 11-line forwarding library; removing it saves little. |
| `levit_dart` utility layer | 3 | Keep; reduce marketing prominence | Its separation is useful to framework authors. App users need not learn the entire dependency graph before writing a controller. Splitting every helper into another package would add release overhead. |
| `Ls`/`Lx` low-level facades vs `Levit` | 3–4 | Keep by layer | Necessary for independent foundation packages. Prefer `Levit` in application docs; do not deprecate foundational accessors merely because the kit forwards them. |
| Builder registration extensions | 2 | Deprecate gradually | `.levitPut`, `.levitLazyPut`, and `.levitLazyPutAsync` are a second spelling of registration that hides the owning scope. Prefer explicit `scope.*`/`Levit.*` calls. |
| `.toBuilder` | 1 | Deprecate | Turns an already-created object into a closure, defeating the point of construction inside the ownership-capture boundary. It is particularly misleading next to builder-only registration guidance. |
| Tests, benchmarks, stress harnesses | 4 | Keep; improve evidence quality | Valuable infrastructure. Test-file count and line coverage do not prove semantic correctness. Add the reproduced behavioral gaps and representative profile/release workloads. |
| Examples and onboarding documentation | 4 potential | Improve | Current guidance is rich, but important task/family workflows are absent from runnable examples and some DartDoc/proposal text describes old behavior. Teach one default path before optional tuning. |

## Meaningful gaps, ordered by payoff

### G1. One observable completion contract for owned asynchronous work

This is the highest-value investment because it strengthens the reason to choose Levit.

**Observed behavior:**

| Path | What happens today |
| --- | --- |
| Task-engine shutdown | Awaits running task bodies; selected existing tests pass. |
| Pending async factory teardown | Waits for construction and closes/rejects late results; selected existing tests pass. |
| Pending async singleton teardown | Scope disposal returns before initialization settles. The later object is disposed and resolution rejected, but disposal did not wait for that cleanup. |
| Owned async `LxWorker` | Owner cleanup completes while a callback is waiting; callback later sees its owned state already disposed. |
| Owned loop | Same lifetime problem as the worker; stop prevents further iterations but does not drain the current body. |
| Flutter scope replacement | New dependencies initialize while the old owner is still closing. |
| Monitor detach | Disables monitoring and launches closure without an awaitable completion result. |

Evidence: [singleton initialization](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_scope/lib/src/core.dart:796), [scope teardown](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_scope/lib/src/core.dart:1120), [worker closure](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/workers.dart:244), [loop stop](/Users/atoumbre/SoftiLab/levit-svg/packages/kits/levit_dart/lib/src/utilities/levit_loop_engine.dart:175), [widget reset](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_flutter_core/lib/src/l_scope.dart:199), [monitor detach](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_monitor/lib/src/core.dart:174).

**Recommended minimum:** expose “stop accepting work”, “request cancellation”, and “finished cleanup” distinctly; give owners a way to await active workers/loops and all pending dependency construction; route cleanup errors to a defined handler; offer an explicit serialized replacement policy for exclusive resources. Avoid pretending that a timeout terminates an arbitrary future.

Flutter's [`State.dispose`](https://api.flutter.dev/flutter/widgets/State-class.html) is synchronous. The solution needs an external completion handle/coordinator and explicit replacement behavior; changing the widget hook to `async` would not make Flutter await it.

For manually created scopes, also clarify whether parent linkage transfers ownership. The current implementation does not retain/close children. Keep that available as an explicit borrowed relationship, but add an owned-child option or a lint/test helper for forgotten child disposal. Do not silently change all existing parent relationships.

### G2. Correct initialization generations and store identity

These are concrete correctness repairs, not requests for a larger abstraction.

- In `LAsyncScope`, the old initialization's error callback reads mutable `_scope`. After an argument change, that field points at the replacement. Capture the scope belonging to that initialization and gate publication/error handling by generation. [Source](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_flutter_core/lib/src/l_async_scope.dart:94).
- `_getStoreTag` returns the explicit tag without including the store definition's identity. Two `LevitStore<int>` definitions resolved with `tag: 'active'` both return the first definition's result. Use definition identity plus variant tag, preferably a typed identity key rather than identity encoded as a hash string. [Source](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_dart_core/lib/src/store.dart:403).

Small reproduced example:

```dart
final scope = LevitScope.root();
final first = LevitStore<int>((_) => 1);
final second = LevitStore<int>((_) => 2);
first.findIn(scope, tag: 'active');  // 1
second.findIn(scope, tag: 'active'); // 1 in this checkout; should be 2
await scope.dispose();
```

### G3. Reactive resource invalidation and a coherent query lifecycle

Levit already has async computed values, stale data, tasks with TTL caches, and families with eviction. **The missing piece is how those primitives compose into reliable refreshable data.**

The family probe created `LxComputed(() => family('x').value)`, attached a worker, invalidated `x`, and changed the new entry to `99`. The computed still read `1`, and its worker received no notification. `invalidate` removes and closes an entry; family lookup itself is not a tracked dependency. [Source](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/family.dart:96).

Decide whether this API means eviction only or refresh of live consumers. Prefer distinct eviction/refresh operations, or a stable per-key observable handle that survives replacement. Then provide a small query recipe covering key identity, freshness, deduplication, retry, cancellation, inactive eviction, and retained data. Add maximum entries/retention budgets for high-cardinality searches.

An established reference is Riverpod's documented behavior: invalidating a listened-to provider recreates its state. This is useful evidence of the workflow users expect, not a requirement to copy its architecture. [Riverpod automatic disposal](https://riverpod.dev/de/docs/concepts2/auto_dispose), [families](https://riverpod.dev/docs/concepts2/family).

### G4. A small structured-task layer

The task engine is worth keeping. The next valuable capabilities are parent-child cancellation, inherited deadlines, and a small group failure policy. Add bounded queue admission, retry classification/jitter, and a typed result when extending the engine.

The existing [structured concurrency proposal](/Users/atoumbre/SoftiLab/levit-svg/proposals/structured_concurrency.md) acknowledges that groups and deadlines are not implemented. The direction fits Levit, but it should follow the lifecycle repairs rather than paper over them. Avoid starting with workflow persistence, arbitrary dependency DAGs, or a large policy matrix.

A useful acceptance scenario is “cancel a project sync, await all child requests and their finally blocks, then close the repository.” Another is “a failed upload cancels its siblings while unrelated background work continues.”

### G5. Typed store overrides and first-class test boundaries

Scoped DI already makes many tests possible. The gap is not basic testability; it is ergonomic, typed replacement of a store recipe and reliable cleanup verification.

Add typed sync/async store lookup and scoped override APIs, an isolated test-scope helper that checks disposal failures, and utilities for waiting for tasks/cleanup without arbitrary sleeps. Prefer the same explicit scope semantics in production and tests. A pure Dart scope description API exposing ancestry, local registrations, and owners would also be useful without installing monitoring.

`context.levit.find<T>(key: dynamic)` currently relies on runtime casts. Store-specific accessors can also make `localOnly` discoverable. Flutter optional lookup currently catches arbitrary errors, which should be separated from “dependency absent.” [Context API](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_flutter_core/lib/src/levit_provider.dart:14).

### G6. Turn safety advice into distributed tooling and real examples

Publish `levit_lints` or provide a supported installation path beyond a repository checkout. The current rule detects the presence of `super.onBeforeClose`/`super.onClose`, but not whether the asynchronous result is awaited or returned. Add focused diagnostics for that, global resolution inside scoped widgets, preconstructed ownership hidden behind `.toBuilder`, and unsafe async worker usage. [Rules](/Users/atoumbre/SoftiLab/levit-svg/packages/tools/levit_lints/lib/src/rules.dart:147), [local-only manifest](/Users/atoumbre/SoftiLab/levit-svg/packages/tools/levit_lints/pubspec.yaml:5).

Add runnable examples of:

- A searchable, paginated list with rapid query changes, cancellation, refresh, error recovery, and eviction.
- A save/upload workflow using `LevitReactiveTasksMixin`, conflict policies, and progress.
- A session switch that replaces scopes while asynchronous cleanup is in flight.
- A store override in a widget test, with disposal assertions.

A scan of `.dart` example sources under `examples/` and package `example/` folders found no direct `LxFamily` or `LevitReactiveTasksMixin` use. This is evidence of an example gap, not lack of user demand. The current async catalog manually writes status after a delay without using the task abstraction, making it a good place to demonstrate the safer intended workflow. [Example](/Users/atoumbre/SoftiLab/levit-svg/examples/async_catalog/lib/main.dart:49).

The [ergonomics proposal](/Users/atoumbre/SoftiLab/levit-svg/proposals/ergonomics_pack.md) still discusses resolver-identity refetching and consuming-view `.put` constructors from an older contract. Refresh that proposal before using it as implementation guidance. A rename from `args` to `deps` is lower priority than making the current contract discoverable.

### G7. Finish the diagnostic experience before expanding transports

The monitor provides good raw ingredients, but its own README explicitly excludes visualization UI. A minimal inspector answering “who owns this?”, “why did this update?”, and “what is still closing?” would make the ownership model tangible. Integrate with Dart/Flutter DevTools or provide a small supported viewer; avoid creating a second general observability platform.

First make shadow-state/event retention configurable, define delivery and drop behavior, and provide awaited flush/close. Distinguish raw internal events from redacted serialized payloads. Current shadow state retains event objects; an obfuscated export does not imply raw values were erased from memory. The WebSocket transport drops sends when disconnected and later replays a snapshot, not a guaranteed event history. [Snapshot cache](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_monitor/lib/src/snapshot.dart:4), [WebSocket transport](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_monitor/lib/src/transports/websocket_transport.dart).

### G8. Persistence and Flutter interoperability should be optional adapters

Useful secondary additions are a versioned state-persistence adapter, a Flutter restoration example, and an observation-only `ValueListenable` adapter. None needs to expand the core lifecycle semantics.

There is already a task-cache storage interface, but it persists task results rather than general application state, and the built-in implementation is memory-only. Start with explicit codecs, keys, and ownership; do not promise automatic serialization of controllers or arbitrary object graphs.

Riverpod's own persistence feature is explicitly experimental and storage-backed. That supports treating persistence as an optional integration rather than a prerequisite for Levit's core proposition. [Riverpod persistence](https://riverpod.dev/de/docs/concepts2/offline).

Pagination, optimistic updates, and form submission deserve tested examples first. A complete form framework, router, HTTP client, ORM, or durable background-job scheduler would dilute the current focus.

## Deprecation recommendations and migrations

### Deprecate with high confidence

| Current surface | Reason | Migration / condition |
| --- | --- | --- |
| `.toBuilder` | Makes preconstruction appear equivalent to owned construction. | Use `() => Controller()` at the owning boundary. For an existing owned implementation, use `bindExisting` where appropriate; for borrowed objects, document ownership explicitly. |
| `LevitReactiveHistoryMiddleware` as general-purpose undo | In-place collection changes are not reversible; batched replay is not atomic to observers. | Introduce opt-in immutable snapshots or explicit domain commands. Keep the old class through a compatibility window and label its limitations. Migrate the Nexus editor before removal. |
| `initialized` alongside `isInitialized` | Same implementation, no distinct meaning. | Prefer `isInitialized`; straightforward deprecation annotation. |
| `computedValue` alongside `requireValue` | Same implementation, misleadingly suggests a computed-only concept. | Prefer `requireValue`. |

History evidence is stronger than “we could simplify this”: adding `2` to `LxList([1])` and calling `undo()` returned `true` while the list remained `[1, 2]`. Restoring a batched pair of scalar changes emitted sums `[1, 0]` rather than only the final `0`. See [collection mutation](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/collections.dart:46), [refresh change records](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/core.dart:844), and [history replay](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/middlewares.dart:621).

### Deprecate as replacement contracts become available

| Current surface | Recommended direction |
| --- | --- |
| Void-only `StoppableService.stop` as a graceful completion contract | Add an awaitable stop/drain contract; migrate internal loops and mixins before deprecating the old interface. Keep a separate immediate cancellation signal if useful. |
| `runGuardedAsync(cancelOnClose: ...)` parameter name | Replace with `discardResultOnClose` or similarly precise naming. Keep the lightweight helper itself. |
| `.levitPut`, `.levitLazyPut`, `.levitLazyPutAsync` | Prefer explicit registration through an owning scope or the application facade. Low urgency; no semantic expansion needed. |
| `LWidgetMonitor` in the main Flutter kit | Move to a recipe or optional compatibility utility; document that it reports mount/unmount only. |

### Demote, do not rush to remove

`LevitSelectionMixin`, `LevitTimeMixin`, `LKeepAlive`, numeric helper types, static-dependency tuning, `batchAsync`, and low-level middleware controls all have identifiable uses. Reduce their prominence and avoid expanding them without demonstrated demand. Deprecating every wrapper would create migration churn while leaving the hard problems untouched.

Do **not** deprecate stores, non-controller resource owners, alias registration, async reactive wrappers, the consuming/owning view distinction, or dedicated isolate task APIs. They represent different ownership or execution needs.

Do not collapse all packages merely to reduce their count. Keep two recommended app imports and explain the rest only when a user needs a lower layer.

## Recommended sequence and success criteria

### Milestone 1 — Make the ownership promise accurate

1. Fix async-scope generation handling and store identity.
2. Define/implement completion behavior for pending DI initialization, workers, loops, and scope replacement.
3. Fix or narrow history guarantees; implement an explicit live-family refresh contract.
4. Add regression cases for every reproduced behavior.

Success: a feature/session can be replaced under load; old work cannot use released owned resources; old initialization cannot affect its replacement; independent stores stay independent; refresh updates attached consumers; undo either correctly restores supported state or rejects unsupported operations.

### Milestone 2 — Make correct usage easy

1. Distribute lints and add awaited-cleanup checks.
2. Add typed store overrides/access, test-scope helpers, and a scope description API.
3. Ship the search/save/session-switch examples and refresh stale docs/proposals.
4. Add monitoring flush/close and retention controls.

Success: a new user can implement and test those workflows from maintained examples without manually managing global middleware or memorizing cleanup exceptions.

### Milestone 3 — Add capabilities that reinforce ownership

1. Add small task groups with cancellation trees and deadlines.
2. Build a coherent query/resource recipe on existing async/family/task primitives.
3. Add a minimal inspector and optional persistence/interoperability adapters.
4. Complete compatible deprecations after migrating repository examples.

Success: each addition removes repeated application code around an existing ownership boundary. Resist unrelated feature expansion.

## Validation and limits

- Inventoried nine package libraries: 61 Dart source files and 16,571 source lines including comments, plus 378 package test files. These numbers describe repository surface, not quality or adoption.
- Read `LLM-Short.txt`, `LLM.txt`, `WHY_LEVIT.md`, package READMEs, public declarations, relevant implementations, test cases, and representative examples. Proposals were treated as proposals rather than shipped APIs.
- **93 selected existing tests passed:** 18 scope/factory/alias tests, 39 family/async-concurrency/batching/stream-completion tests, 28 task/shutdown/conflict/queue/cache tests, and 8 Flutter local-store contract tests.
- **Two additional Flutter probes passed by asserting the observed defects:** replacement starts before old cleanup finishes; obsolete async initialization failure closes the replacement scope. These passes confirm the findings, not desirable behavior.
- A separate pure Dart probe reproduced store-tag collision, pending-singleton teardown timing, non-cascading manual parent disposal, worker/loop lifetime escape, stale family observation after invalidation, non-atomic batch undo, and ineffective collection undo.
- Audit scripts and raw results were kept under `/private/tmp`; no runtime or test source in the repository was changed. These probes should be converted into permanent regression tests when fixes are implemented.
- This was a feature/design audit with targeted behavioral verification, not a full code review, full CI run, memory profiling campaign, or release certification. No whole-repository formatting was run on the already modified checkout.
- The existing benchmark report identifies its run as **debug mode, test profile**. It is useful harness evidence, but insufficient to claim production superiority or validate every optimization knob. [Benchmark environment](/Users/atoumbre/SoftiLab/levit-svg/reports/bench_mark_report.md:4). Profile/release measurements on representative target devices, with monitoring settings disclosed, would provide stronger evidence.
- No external usage telemetry was available. Low example usage alone was not used as a reason to remove a feature. External primary documentation was used only to check relevant lifecycle and data-workflow expectations.

**Overall recommendation: stabilize and simplify around ownership. Levit needs fewer surprising lifetime exceptions and better end-to-end workflows more than it needs a larger feature list.**
