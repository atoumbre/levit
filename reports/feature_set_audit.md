> Historical pre-0.1.0 audit. Its API conclusions are superseded by the
> [implemented release plan](release_0.1.0_plan.md) and
> [progress report](release_0.1.0_progress.md).

# Levit feature-set audit

Audited 2026-09-05 at commit `539f130` (package versions `0.0.11`).

**0.0.12 disposition (2026-09-05):** The approved release narrows this audit's
recommendations to lifecycle correctness and API cleanup. The original findings
below describe 0.0.11; the following decisions supersede its proposed staging.

| Finding | Release disposition |
| :-- | :-- |
| G1 nullable reads | Fixed with read-only `call()`; writes use `.value`. Removed write syntax and migrated resolved reactive calls. |
| G2 factory ownership | Registering scopes own disposable results, including concurrent async creation during removal. Removal awaits cleanup; replacement requires awaited deletion. |
| G3 async batching | Retained and isolated by execution-zone context. Independent outside notifications, nested propagation, errors, escaped work, and history boundaries have regressions. Values remain shared. |
| G4 task shutdown | Awaitable engine disposal and `onBeforeClose` drain hooks precede resource cleanup. No timeout or hard cancellation; task groups and deadlines remain deferred. |
| G5 bootstrap | Explicit `enableAutoLinking()` retained. Monitoring no longer changes ownership configuration. Preconstructed registration extensions and consuming-view `.put` constructors removed. |
| G6 stores/views | Ancestor reuse retained; `localOnly` added. Consuming views use scope/`args` changes. The `args` name remains; broader ergonomics deferred. |
| G7 executable guidance | Regression and documentation fixtures added within existing packages. Lint package remains unpublished. No new testing package. |
| G8/G9 broader tooling/data features | Inspector, monitor shutdown redesign, persistence, and query abstractions excluded from this release. |
| Package structure | Eight publishable runtime packages coordinated at 0.0.12; no consolidation. |

Consumer changes are documented in [MIGRATION_0.0.12.md](../docs/MIGRATION_0.0.12.md).
Release checks and regenerated evidence are recorded in the
[release validation report](release_0.0.12_validation.md); implementation alone
does not authorize publication.

**Assessment: keep the ownership runtime, narrow the convenience surface, and prioritize lifecycle correctness and testing tools over additional abstractions.** Levit has a credible purpose in applications with feature, route, request, and resource lifetimes. Its strongest features reinforce that purpose. Its weakest APIs make creation, mutation, or lifetime implicit in surprising ways.

This is a repository-based product and API assessment, using the project guidance, all nine package READMEs, exported implementation, relevant tests, examples, and proposals. Usefulness is judged for the medium-to-large Dart/Flutter applications described in `WHY_LEVIT.md`; it is not a measurement of external adoption. Feature families are grouped where constructors and helpers serve the same purpose. “Situational” means valuable for a narrower workload, not a reason to remove a feature.

**Feature-by-feature assessment**

| Feature family | Usefulness | Recommendation and rationale |
| :-- | :-- | :-- |
| Hierarchical scopes, local overrides, explicit scope execution, `runInScope` | Essential | **Invest.** The central answer to feature/request/test ownership. Preserve pure Dart support and the distinction between app and child lifetimes. |
| Eager/lazy/async registration and concurrent async singleton resolution | High | **Keep.** Covers real initialization costs and shared services without a separate DI system. |
| Tags, local registration probes, `bindExisting` aliases | High in larger apps | **Keep.** Multiple implementations and ports need disambiguation. Non-owning aliases correctly avoid creating another owner. |
| `isFactory` per-resolution dependencies | Situational | **Repair ownership before promoting.** Fresh instances are useful, but resolved controllers currently escape scope teardown; see G2. |
| `permanent` registrations | Situational | **Keep as advanced.** Surviving a non-forced reset is useful. It does not extend lifetime beyond scope disposal; keep that distinction explicit. |
| `Levit` facade, low-level `Ls`, explicit scopes, `context.levit` | High | **Keep the layers; teach one default per environment.** Context lookup is important in Flutter; explicit or contextual scope execution remains useful in Dart. Do not remove low-level APIs merely because kits re-export them. |
| Instance/future registration extensions | Low incremental value | **Deprecate the preconstructed forms.** Construction has already happened, defeating lazy creation and reactive capture. Builder extensions can remain. |
| Controllers and reusable `LevitResourceOwnership` | Essential | **Invest.** Shared ownership for controller and non-controller resources is a strong architectural feature. |
| `own` / `autoDispose`, awaited LIFO cleanup, idempotence, aggregated failures | Essential | **Protect and extend consistently.** These guarantees differentiate Levit. Keeping both names is harmless compared with changing established application code. |
| Automatic reactive linking | High, but fragile to setup | **Keep; improve bootstrap and diagnostics.** Field ownership should not silently depend on a missed startup call or enabling a monitor. Explicit ownership remains useful for dynamic resources. |
| `runGuardedAsync` | Medium | **Keep as a small helper.** Useful for suppressing a returned result after close. Document that it does not stop callback side effects or replace task cancellation. |
| `LevitStore`, `LevitAsyncStore`, `LevitRef` | Medium–high | **Keep; clarify semantics.** Portable recipes avoid controller boilerplate. They run once, do not reactively rebuild from reads, and can inherit an ancestor instance. These contracts need clearer guidance. |
| `LxVar`, `.lx`, equality, named/sensitive values | Essential | **Keep.** Small mutable sources support focused state. `.lx` itself is useful and is not a deprecation candidate. |
| Combined `value()` read / `value(newValue)` write syntax | Low incremental value | **Fix immediately; retire the dual-purpose write form in a staged migration.** Nullable no-argument reads currently mutate the value. Keep a safe read form and explicit writes. |
| `LxBool`, `LxInt`, `LxDouble` helpers | Medium | **Maintain.** Cheap convenience, little architectural burden. Additional numeric/operator helpers are low priority. |
| `LxState`, reducer updates, exposure as `LxReactive` | Medium–high | **Keep.** Controlled state transitions suit immutable models. This is a distinct style; it does not make the underlying object deeply immutable. |
| Reactive lists, maps, sets and collection helpers | High | **Keep.** Essential for lists and editors. Explain that arbitrary mutable fields inside collection elements are not automatically deeply reactive. |
| Synchronous computed values, dependency tracking, custom equality | Essential | **Invest.** Shared derivation and narrow notifications are central to the framework. |
| Computed `staticDeps`, eager mode, deferred computations, function extensions | Situational | **Keep advanced and stable.** Useful optimization/scheduling controls; keep them out of the introductory path. Benchmark before adding more modes. |
| Async computed values; `latest` and `exhaustLatest` | High | **Keep.** Derived remote state and coalesced refreshes are common. Explain publication control separately from cancelling work or side effects. |
| `LxStatus`, idle/waiting/success/error, retained last value | High | **Keep.** A consistent async vocabulary is valuable. Stale-value display already exists; do not list it as a missing feature. |
| `LxFuture`, `LxStream`, stream binding/transforms, completion/restart policies | High | **Keep.** Interoperability with existing Dart async sources is essential. Retained completion and rebinding solve practical stream lifecycles. |
| `LxFamily`, keyed resources, explicit invalidation, inactivity eviction | High for dynamic data | **Invest selectively.** Useful for per-item streams and caches. Improve invalidation consumption and bounded retention before adding another generic provider abstraction. |
| Workers, status/transition watchers, reactive debounce/throttle | High | **Keep.** A clear home for side effects. Separate observing a source from scheduling arbitrary imperative work. |
| Worker statistics and monitoring controls | Situational | **Keep configurable.** Useful for diagnostics; assess default instrumentation cost with representative workloads. |
| Synchronous batching | High | **Keep as the default commit mechanism.** Related state changes should produce coherent updates. It is not a rollback transaction. |
| Async batching across awaits | Questionable current contract | **Stop recommending for long I/O; repair or deprecate current global suppression semantics.** An unrelated source can be held until another async batch completes; see G3. |
| `LWatch` | Essential | **Keep as the primary Flutter reactive boundary.** Especially useful around small subtrees. |
| `LBuilder`, `LSelectorBuilder`, `LStatusBuilder` | High | **Keep all three.** Explicit subscriptions, equality-filtered local derivation, and async branches have different jobs; they are not redundant merely because `LWatch` can express similar UI. |
| `LScope`, `LAsyncScope`, scope construction helpers | Essential | **Keep.** Map ownership to subtree mount/unmount and async initialization. |
| `LView`, `LAsyncView`, scoped variants, store constructors, subclass/builder styles | High | **Keep; standardize update behavior.** Consuming an existing dependency and owning a child scope are distinct needs. Resolve sync/async `args` inconsistency rather than collapsing everything into one configurable widget. |
| `LView.put`, `LAsyncView.put` | Low incremental value | **Deprecate.** These register into the existing scope from a consuming view. Prefer explicit scope registration or the scoped view constructors. |
| Route scopes and reactive route visibility | High in routed apps | **Keep.** Route identity/coverage is a meaningful boundary beyond ordinary subtree lifetime. |
| Scope capture and dialog/bottom-sheet helpers | High | **Keep.** They address a concrete dependency lookup problem across overlay boundaries. |
| Task engine: priorities, concurrency limits, retries, conflict policies, cancellation | High for operational apps | **Invest in lifecycle completion.** Uploads, synchronization, and overlapping commands justify a managed engine. The six conflict policies have distinct behavior; reduce onboarding complexity with examples, not removal. |
| Reactive tasks, selectors, progress, blocking state, task events/tracker | High | **Keep.** Useful UX and diagnostics from one execution model. Engine-only and reactive mixins serve different consumers. |
| Task result cache, TTL, serialization, custom cache provider | Medium–high | **Keep optional.** Useful infrastructure already exists. It is not a complete observable query cache or offline data layer. |
| Explicit isolate task APIs | Situational, high for CPU work | **Keep explicit.** A typed entrypoint/input boundary is clearer than a boolean flag on ordinary closures. |
| Time mixin: debounce, throttle, intervals, countdown | Medium | **Maintain.** Lifecycle-bound timers remove boilerplate. Do not advertise tick-subtraction countdowns as precise wall-clock deadlines. |
| Loop engine, stoppable services, isolated loops | Situational | **Keep advanced.** Sequential repeated work and pausable services differ from individual queued tasks. Align stop/close completion with ownership guarantees. |
| App lifecycle and loop lifecycle mixins | Medium–high | **Keep.** Pausing work on app lifecycle transitions is a practical Flutter integration. |
| Selection mixin | Situational | **Freeze scope; keep optional.** Useful convenience, weak differentiation. No evidence here justifies forcing migration out of it. |
| `LKeepAlive` | Situational | **Maintain.** Small Flutter convenience; not a core selling point or meaningful maintenance burden. |
| `LWidgetMonitor` | Low–medium | **Keep as optional convenience.** Mount/unmount callbacks are useful, but this does not detect viewport visibility. Fix references to nonexistent `LListItemMonitor`. |
| DI/reactive middleware, token registration, interception | High for integrations | **Keep.** Stable extension points enable diagnostics and cross-cutting concerns. Avoid making middleware necessary for ordinary business logic. |
| Reactive history / undo-redo middleware | High for editors; low elsewhere | **Keep optional and improve scoped use.** Nexus Studio demonstrates a real use. It needs deliberate filtering and history lifetime; it is not a general persistence or application rollback system. |
| Monitor events, redaction, snapshots, custom events, console/file/socket transports | High for complex apps | **Invest in usable inspection and awaited shutdown.** The transport foundation is useful; a ready inspection workflow would make it much easier to benefit from. Preserve independence from the task kit. |
| Native analyzer lints | High | **Invest.** Preventing ownership errors at edit time directly supports Levit's purpose. Four current rules are a foundation. |
| Kits and separate foundational packages | High | **Keep recommended `levit` and `levit_flutter` entry points.** Thin exports are not a sufficient reason to impose package migration. Explain the lower-level packages as advanced choices. |
| Examples, stress tests, benchmark harness, test suite | High | **Invest in behavioral contracts and current evidence.** Strong breadth, but feature usefulness and lifecycle correctness are not proved by line coverage alone. |

**Meaningful gaps, in priority order**

**G1 — Safe nullable reads. Immediate correctness fix.**

`LxVar<String?>('kept')()` returns `null` and changes the stored value to `null`. The omitted optional argument becomes null, and `v is T` succeeds for nullable `T`. This is especially dangerous because the documented read operation becomes a write during a build or computation. Reproduced on this checkout. Correct omitted-argument handling first; use explicit `.value = ...` for writes in the preferred API and migrate away from the combined read/write form. Add regression cases for nullable concrete types, `Object?`, and `dynamic`.

Evidence: [call implementation](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/base_types.dart:27).

**G2 — An explicit owner for every factory result. High priority.**

With auto-linking enabled, a controller returned by `lazyPut(..., isFactory: true)` receives lifecycle initialization, but remains open after its scope is disposed; its reactive field also remains open. Factory resolution bypasses cached instance storage, while teardown traverses instantiated registrations. This conflicts with the broad ownership promise unless callers are clearly responsible for every result.

Choose and test an explicit policy: scope-owned transient tracking, caller-owned results with mandatory transfer guidance, or separate APIs for each. Do not silently change lifetime for all factory consumers. Include asynchronous factory completion during teardown and multiple results in validation.

Evidence: [factory resolution](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_scope/lib/src/core.dart:774), [teardown](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_scope/lib/src/core.dart:1082).

**G3 — Async batch isolation. High priority.**

A pending `Levit.batchAsync` with no mutations can delay a notification from an unrelated reactive outside its zone. The probe observed zero notifications before the batch completed and one afterward. Global batch depth spans the await. This can stall unrelated UI or request state when batching network work.

Prefer awaiting I/O first, then committing related state synchronously with `Levit.batch`. Either make async batching isolate unrelated notifications or explicitly retire its current semantics with a migration path. Document that batching provides notification coordination, not transaction isolation or rollback.

Evidence: [async batching](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/core.dart:175).

**G4 — Cancellation versus completed shutdown. High priority.**

`LevitTaskEngine.dispose()` marks running work cancelled and returns while the task body can still be running. The probe confirmed this. Cooperative cancellation is legitimate, but awaiting an owner’s disposal does not currently imply that its task bodies have finished touching owned resources. Workers and loop services need equally clear contracts.

Add an explicit awaitable drain/join operation with bounded shutdown policy, and define when dependent resources may close. Then add task groups, inherited deadlines, cancellation trees, and failure policies. The existing structured-concurrency proposal identifies these additions; its private same-ID engine groups are not already public parent/child workflow groups. Preserve the existing task API while building the stronger model.

Evidence: [engine disposal](/Users/atoumbre/SoftiLab/levit-svg/packages/kits/levit_dart/lib/src/utilities/levit_task_engine.dart:887), [proposal](/Users/atoumbre/SoftiLab/levit-svg/proposals/structured_concurrency.md).

**G5 — Ownership bootstrap that is difficult to misuse. High priority.**

Construction inside registration is materially different from registering an existing controller. The probe showed that the prebuilt controller’s field stayed open after disposal, while a builder-created controller’s field closed. Separately, `LevitMonitor.attach` enables auto-linking, so diagnostics can change cleanup behavior if the app omitted its own bootstrap. The Flutter-core quick start contains a controller field without enabling auto-linking or owning that field explicitly.

Centralize the recommended bootstrap, correct all quick starts, and extend lints to unsafe instance registration and missing ownership. Monitoring should observe an explicitly configured lifecycle policy. Retain explicit `own` for dynamic resources; changing the default globally needs compatibility analysis.

Evidence: extensions (historical source `packages/core/levit_scope/lib/src/extensions.dart:3`), [bootstrap](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_dart_core/lib/src/core.dart:284), [monitor attach](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_monitor/lib/src/core.dart:150), [quick start](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_flutter_core/README.md).

**G6 — Unambiguous store and view semantics. High priority for adoption.**

Stores are initialization recipes, not reactive computations. Existing tests explicitly verify that store builders ignore dependency changes. Resolving a store in a parent first causes a child lookup to reuse that instance; the probe confirmed this. Thus “per-scope recipe” needs qualification: sibling isolation with no ancestor instance does not imply a fresh instance in every descendant. Provide an explicit local-instantiation/override path and examples showing both inheritance and isolation. Keep reactive derivation in `LxComputed` or return a reactive object from a store; the guidance’s counter recipe currently returns an integer snapshot.

Sync views re-resolve on changed `args`, while async views additionally react to resolver identity without `args`. Define one understandable contract and adopt the proposed `deps` naming with a compatibility alias. Adding a new name alone will not remove accidental async refetching. `putOrFind` parity and lightweight scope ancestry metadata are useful smaller improvements already covered by the ergonomics proposal.

Evidence: [store lookup](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_dart_core/lib/src/store.dart:113), [static store test](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_dart_core/test/store/levit_store_test.dart:33), [view updates](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_flutter_core/lib/src/view.dart:149), [ergonomics proposal](/Users/atoumbre/SoftiLab/levit-svg/proposals/ergonomics_pack.md).

**G7 — A first-class testing kit and executable documentation. High return on effort.**

The project guidance explicitly describes a manual widget-test harness “until levit_tests ships pumpLevitApp”; no such package exists in this checkout. Provide isolated scopes, explicit overrides, awaited teardown, resource leak assertions, and controllable time for task/timer tests. Make copyable examples compile in CI. Current documentation drift includes `LListItemMonitor` versus exported `LWidgetMonitor`, and a monitor README example passing `filter` to `attach` even though filtering is configured with `setFilter`.

Prioritize outcome tests for the reproduced edge cases. The checked-in coverage report is dated May 11 and does not establish coverage of this September checkout. Regenerate quality reports against release commits rather than treating the old 100% report as current evidence.

Evidence: [test guidance](/Users/atoumbre/SoftiLab/levit-svg/LLM.txt:345), [lint rules](/Users/atoumbre/SoftiLab/levit-svg/packages/tools/levit_lints/README.md), [coverage report](/Users/atoumbre/SoftiLab/levit-svg/reports/packages_test_coverage.md).

**G8 — A complete debugging workflow. Medium–high priority.**

The monitor explicitly excludes visualization UI. Deliver a small inspector that answers the framework’s own questions: which scope owns this object, which read caused this rebuild, which resources remain after route exit, and which task is still running. Provide a ready task-event adapter outside the monitor core. Add an awaitable monitor shutdown/flush path: `detach` currently starts close without awaiting it and suppresses close errors, which limits reliable final event export.

A minimal ownership/rebuild inspector has more strategic value than more widget sugar. This recommendation concerns the tooling present in this repository, not a claim that no external tooling exists.

Evidence: [monitor boundary](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_monitor/README.md), [detach](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_monitor/lib/src/core.dart:177).

**G9 — A cohesive remote-data recipe. Medium priority, demand-led.**

Families, async computed values, retained last values, retries, deduplication via task policies, and TTL result caching already exist. What is missing is a documented composition for freshness, observable invalidation, paginated loading, optimistic updates/rollback, and reconnect refresh. Start with one realistic example and reusable adapters; introduce a query abstraction only if the composition remains repetitive. General durable state restoration is also distinct from task-result caching and diagnostic snapshots; add it as an optional integration when actual app requirements justify it.

Evidence: families (historical source `packages/core/levit_reactive/lib/src/family.dart:37`), [async status](/Users/atoumbre/SoftiLab/levit-svg/packages/core/levit_reactive/lib/src/async_status.dart:3), [cache contract](/Users/atoumbre/SoftiLab/levit-svg/packages/kits/levit_dart/lib/src/utilities/task_engine_models.dart:597).

**Deprecation decisions**

| Candidate | Decision | Migration |
| :-- | :-- | :-- |
| `LevitInstanceExtension.levitPut` and `.levitLazyPut` | **Recommend deprecation. High confidence.** Eagerly-created resources defeat capture; “lazy” cannot delay their creation. | Move construction inside `Levit.put(() => ...)` / `lazyPut(() => ...)`. For deliberately external objects, establish explicit ownership and cleanup. |
| `LevitAsyncInstanceExtension.levitLazyPutAsync` on an existing `Future` | **Recommend deprecation. High confidence.** Work already started; factory mode only re-awaits the same future. | Register a `Future<T> Function()` that starts fresh work when resolved. Preserve builder-based extensions. |
| `LView.put` / `LAsyncView.put` | **Recommend deprecation. Medium–high confidence.** Consuming views mutate the nearest existing scope; unmounting the view does not remove that registration. | Use `LScopedView.put` / `LScopedAsyncView.put` for view ownership, or register in the intended existing scope and consume with `LView` / `LAsyncView`. Preserve the original lifetime intentionally. |
| Dual-purpose mutable `call([value])` | **Recommend staged API retirement after an immediate bug fix.** Read/write ambiguity has a demonstrated failure. | Explicit `.value` writes; retain safe read ergonomics. Include nullable reads in migration validation. |
| Current cross-await global batching behavior | **Conditional deprecation.** Keep only if unrelated state can be isolated and the contract is made clear. | Await external work, then use a short synchronous `batch`. |
| View `args` | **Deprecate only after `deps` exists and semantics are aligned.** This is a migration candidate, not an obsolete API today. | Compatibility alias plus analyzer fix, as proposed in the ergonomics document. |

Do **not** deprecate stores, worker helpers, selectors, route scopes, task policies, history, or the thin `levit` package solely to reduce feature count. Each has a defensible purpose. Keep selection, keep-alive, widget monitoring, countdowns, and specialized computed modes stable but out of the main product narrative. There is insufficient adoption evidence to justify removing them.

Deprecation should mean annotations, replacements, documented lifetime differences, and migration examples before removal. No APIs were changed or marked deprecated as part of this audit.

**Suggested delivery order**

1. **Correctness release:** nullable reads; factory ownership contract; async-batch isolation; consistent bootstrap examples; regression tests for each.
2. **Trust and ergonomics release:** test helpers, store inheritance/local overrides, aligned view dependencies, explicit shutdown completion, deprecation annotations and migrations.
3. **Differentiation work:** ownership/rebuild inspector, structured task lifetimes, one complete remote-data example.
4. **Demand-led additions:** persistence adapters and other domain conveniences. Avoid new routing frameworks, mandatory code generation, or broader utility bundles without concrete consumer needs.

**Validation and limits**

- Ran **70 existing tests**, all passing: 42 covering core auto-linking/stores/generic ownership, 13 covering task conflicts/cleanup/mixin lifecycle, and 15 covering reactive call syntax/nullable values/async batching/families.
- Ran six isolated behavioral probes, confirming nullable read mutation, missed capture on prebuilt registration, undisposed factory results, ancestor store reuse, non-draining task disposal, and unrelated notification suppression during async batching.
- A minimal monitor using `ConsoleTransport` successfully compiled to JavaScript. The unconditional `dart:io` import alone is therefore not sufficient evidence to claim the entire monitor is unusable on web; transport-specific runtime support was not assessed.
- Flutter view recommendations are based on implementation and existing test inspection; no Flutter test suite was executed. Full CI, fresh coverage, performance benchmarks, and external adoption research were not run.
- Findings distinguish observed behavior from proposed policy. The task-drain, store-inheritance, and async-batch issues require deliberate contract decisions; they should not be “fixed” through unannounced lifetime changes.
