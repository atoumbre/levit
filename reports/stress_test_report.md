# Levit Framework Stress Test Report

> **Generated on:** 2026-01-28

## Performance Summary

### Levit Reactive (Core)

| Scenario | Description | Measured Action | Result |
| :--- | :--- | :--- | :--- |
| Collections LxList Bulk Assign - 1M items | Tests performance of assigning a large list. | Assigned 5M items to LxList | **1ms** |
| Watchers (LxWorker) LxWorker Subscribe/Unsubscribe Churn - 10k cycles | Tests efficiency of creating and disposing LxWorker subscriptions. | Performed 10000 LxWorker create/dispose cycles | **11ms** |
| Watchers (LxWorker) LxWorker Callback Flood - 100k rapid updates | Tests LxWorker callback performance under flood conditions. | Flooded 100000 updates | **26ms** |
| Async Types LxFuture Rapid Create - 1000 LxFuture instances | Tests rapidly creating LxFuture instances. | Created 1000 LxFuture instances | **124ms** |
| Watchers (LxWorker) LxWorker.isTrue and LxWorker.isFalse - Toggle stress | Tests boolean watchers under rapid toggling. | Toggled 10000 times | **11ms** |
| Async Types LxStream High Throughput - 10k events | Tests LxStream with a high-throughput stream. | Emitted 10000 events | **103ms** |
| Middleware Middleware Pipeline Overhead - 100 middlewares, 10k updates | Measures overhead of a middleware pipeline. | Middleware Pipeline: Processed 10000 updates with 100 middlewares | **47ms** |
| Async Types LxAsyncComputed Rapid Invalidation - 500 invalidations | Tests LxAsyncComputed behavior under rapid invalidation. | Invalidated 500x | **202ms** |
| Async Types LxAsyncComputed Rapid Invalidation - 500 invalidations | Tests LxAsyncComputed behavior under rapid invalidation. | Final status | **-** |
| Lx Core Bulk Update - 1M rapid updates to a single Lx | Measures throughput of rapid value updates on a single Lx<int>. | Performed 1000000 updates | **29ms** |
| Async Types Async Race - 50 concurrent LxAsyncComputed on same source | Tests many async computeds racing on the same source. | 50 async computeds, 0 resolved | **202ms** |
| Lx Core Listener Fan-Out - 50k listeners on a single Lx | Tests notification broadcast to 50,000 listeners. | Notified 50000 listeners | **5ms** |
| Lx Core Listener Add/Remove Churn - 50k add/remove cycles | Tests efficiency of listener management under churn. | Performed 100000 add/remove ops | **8ms** |
| LxComputed Deep Chain - 5000 LxComputed nodes | Tests propagation through a deeply chained dependency graph. | Created 5000 computed nodes | **634ms** |
| LxComputed Deep Chain - 5000 LxComputed nodes | Tests propagation through a deeply chained dependency graph. | Propagated change through 5000 nodes | **1ms** |
| LxComputed Fan-In - One LxComputed observing 5k sources | Tests computed that aggregates many sources. | Fan-In Setup: Initial computation with 5000 sources | **4ms** |
| LxComputed Fan-In - One LxComputed observing 5k sources | Tests computed that aggregates many sources. | Fan-In Single Update: Propagated single source change | **0ms** |
| Collections LxList Mutation Burst - 500k random ops | Tests rapid add/remove/insert operations. | Performed 500000 mutations | **3295ms** |
| Collections LxMap Bulk Insert - 1M entries | Tests mass insertion into LxMap. | Inserted 1000000 entries | **420ms** |
| Collections LxMap Bulk Insert - 1M entries | Tests mass insertion into LxMap. | Cleared 1000000 entries | **41us** |
| Collections LxMap Update Flood - 100k key updates | Tests rapidly updating existing map values. | Updated 100000 keys | **25ms** |
| Collections Collection Computed Propagation | Tests computed that observes collection changes. | Added 10k items, computed sum=5000050000 | **9ms** |

### Levit DI (Dependency Injection)

| Scenario | Description | Measured Action | Result |
| :--- | :--- | :--- | :--- |
| DI Scoping Deep Nesting - 1000 nested scopes | Tests resolution through deeply nested scopes. | Created 1000 nested scopes | **2ms** |
| DI Scoping Deep Nesting - 1000 nested scopes | Tests resolution through deeply nested scopes. | Resolved root dependency through 1000 layers | **3ms** |
| DI Scoping Shadowing - Resolution at each level | Tests that shadowing works correctly at all levels. | Performed 1000 shadowed lookups at depth 100 | **1ms** |
| DI Registration Bulk Put/Find - 500k services | Tests mass registration and lookup performance. | Registered 500000 services | **385ms** |
| DI Lifecycle Disposable Cleanup - 10k services | Verifies onClose is called for all disposable services. | Disposed 10000 services | **5ms** |
| DI Registration Bulk Put/Find - 500k services | Tests mass registration and lookup performance. | Resolved 500000 services | **219ms** |
| DI Lifecycle Concurrent Find - 10k concurrent futures | Tests concurrent resolution safety. | Resolved 10000 concurrent requests | **157ms** |
| DI Registration Lazy Instantiation Burst - 50k lazy services | Tests lazy instantiation triggered all at once. | Instantiated 50000 lazy services | **32ms** |
| DI Registration Factory Create Churn - 100k factory instances | Tests factory pattern performance. | Created 100000 factory instances | **25ms** |
| DI Lifecycle Put/Delete Cycles - 100k iterations | Tests rapid put/delete lifecycle churn. | Performed 100000 put/delete cycles | **63ms** |

### Levit Flutter (UI Binding)

| Scenario | Description | Measured Action | Result |
| :--- | :--- | :--- | :--- |
| LWatch Fan-In - LWatch observing 5000 sources | Tests LWatch with many dependencies. | LWatch Fan-In: Initial build with 5000 sources, single update rebuild | **15ms** |
| LStatusBuilder State Switch - 1000 status transitions | Tests LStatusBuilder state switching performance. | LStatusBuilder State Switch: 1000 transitions | **29ms** |
| LScope Deep Tree - 500 nested LScope widgets | Tests resolution through deeply nested LScope widgets. | Resolved deep scope through 500 layers | **0ms** |
| LStatusBuilder Flood - 500 LStatusBuilder widgets | Tests many LStatusBuilder widgets in a single frame. | LStatusBuilder Flood: 500 widgets updated | **9ms** |
| LWatch Rapid Rebuild - 60fps simulation for 2 seconds | Simulates 60fps updates and measures rebuild performance. | Rapid Rebuild: 1200 builds over 1200 frame updates | **744ms** |
| LScope Churn - 200 mount/unmount LScope cycles | Tests LScope mount/unmount performance. | LScope Churn: 200 mount/unmount cycles | **1034ms** |
| LView Lifecycle - 100 mount/unmount cycles | Tests LView controller lifecycle under churn. | LView Lifecycle: 100 mount/unmount cycles | **661ms** |
| LView Controller Access - 10k access calls | Measures controller access performance from LView. | Controller Access: 10k Levit.find calls | **7ms** |
| LWatch Subscribe Cleanup - 5000 mount/unmount cycles | Verifies LWatch cleans up subscriptions correctly. | LWatch Subscribe Cleanup: 5000 mount/unmount cycles | **6986ms** |

## Raw Execution Logs
<details>
<summary>Click to view full logs</summary>

```text
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collections LxList Bulk Assign - 1M items] Assigned 5M items to LxList in 1ms
[lib/levit_reactive/watcher_stress_test.dart] [Stress Test: Watchers (LxWorker) LxWorker Subscribe/Unsubscribe Churn - 10k cycles] Performed 10000 LxWorker create/dispose cycles in 11ms (909 ops/ms)
[lib/levit_reactive/watcher_stress_test.dart] [Stress Test: Watchers (LxWorker) LxWorker Callback Flood - 100k rapid updates] Flooded 100000 updates in 26ms
[lib/levit_reactive/async_stress_test.dart] [Stress Test: Async Types LxFuture Rapid Create - 1000 LxFuture instances] Created 1000 LxFuture instances in 124ms, 1000 resolved
[lib/levit_reactive/watcher_stress_test.dart] [Stress Test: Watchers (LxWorker) LxWorker.isTrue and LxWorker.isFalse - Toggle stress] Toggled 10000 times in 11ms
[lib/levit_reactive/async_stress_test.dart] [Stress Test: Async Types LxStream High Throughput - 10k events] Emitted 10000 events in 103ms, received 10000 notifications
[lib/levit_reactive/middleware_stress_test.dart] [Stress Test: Middleware Middleware Pipeline Overhead - 100 middlewares, 10k updates] Middleware Pipeline: Processed 10000 updates with 100 middlewares in 47ms
[lib/levit_reactive/async_stress_test.dart] [Stress Test: Async Types LxAsyncComputed Rapid Invalidation - 500 invalidations] Invalidated 500x in 202ms, compute called 0 times
[lib/levit_reactive/async_stress_test.dart] [Stress Test: Async Types LxAsyncComputed Rapid Invalidation - 500 invalidations] Final status: LxWaiting<int>(lastValue: null)
[lib/levit_reactive/lx_core_stress_test.dart] [Stress Test: Lx Core Bulk Update - 1M rapid updates to a single Lx] Performed 1000000 updates in 29ms (34483 ops/ms)
[lib/levit_reactive/async_stress_test.dart] [Stress Test: Async Types Async Race - 50 concurrent LxAsyncComputed on same source] 50 async computeds, 0 resolved in 202ms
[lib/levit_reactive/lx_core_stress_test.dart] [Stress Test: Lx Core Listener Fan-Out - 50k listeners on a single Lx] Notified 50000 listeners in 5ms
[lib/levit_reactive/lx_core_stress_test.dart] [Stress Test: Lx Core Listener Add/Remove Churn - 50k add/remove cycles] Performed 100000 add/remove ops in 8ms (12500 ops/ms)
[lib/levit_scope/scope_stress_test.dart] [Stress Test: DI Scoping Deep Nesting - 1000 nested scopes] Created 1000 nested scopes in 2ms
[lib/levit_scope/scope_stress_test.dart] [Stress Test: DI Scoping Deep Nesting - 1000 nested scopes] Resolved root dependency through 1000 layers in 3ms
[lib/levit_scope/scope_stress_test.dart] [Stress Test: DI Scoping Shadowing - Resolution at each level] Performed 1000 shadowed lookups at depth 100 in 1ms
[lib/levit_reactive/computed_stress_test.dart] [Stress Test: LxComputed Deep Chain - 5000 LxComputed nodes] Created 5000 computed nodes in 634ms
[lib/levit_reactive/computed_stress_test.dart] [Stress Test: LxComputed Deep Chain - 5000 LxComputed nodes] Propagated change through 5000 nodes in 1ms
[lib/levit_reactive/computed_stress_test.dart] [Stress Test: LxComputed Fan-In - One LxComputed observing 5k sources] Fan-In Setup: Initial computation with 5000 sources in 4ms
[lib/levit_reactive/computed_stress_test.dart] [Stress Test: LxComputed Fan-In - One LxComputed observing 5k sources] Fan-In Single Update: Propagated single source change in 0ms
[lib/levit_scope/registration_stress_test.dart] [Stress Test: DI Registration Bulk Put/Find - 500k services] Registered 500000 services in 385ms
[lib/levit_scope/lifecycle_stress_test.dart] [Stress Test: DI Lifecycle Disposable Cleanup - 10k services] Disposed 10000 services in 5ms (onClose count: 10000)
[lib/levit_scope/registration_stress_test.dart] [Stress Test: DI Registration Bulk Put/Find - 500k services] Resolved 500000 services in 219ms
[lib/levit_scope/lifecycle_stress_test.dart] [Stress Test: DI Lifecycle Concurrent Find - 10k concurrent futures] Resolved 10000 concurrent requests in 157ms
[lib/levit_scope/registration_stress_test.dart] [Stress Test: DI Registration Lazy Instantiation Burst - 50k lazy services] Instantiated 50000 lazy services in 32ms
[lib/levit_scope/registration_stress_test.dart] [Stress Test: DI Registration Factory Create Churn - 100k factory instances] Created 100000 factory instances in 25ms (4000 ops/ms)
[lib/levit_scope/lifecycle_stress_test.dart] [Stress Test: DI Lifecycle Put/Delete Cycles - 100k iterations] Performed 100000 put/delete cycles in 63ms
[lib/levit_flutter/lwatch_stress_test.dart] [Stress Test: LWatch Fan-In - LWatch observing 5000 sources] LWatch Fan-In: Initial build with 5000 sources, single update rebuild in 15ms
[lib/levit_flutter/status_builder_stress_test.dart] [Stress Test: LStatusBuilder State Switch - 1000 status transitions] LStatusBuilder State Switch: 1000 transitions in 29ms
[lib/levit_flutter/lscope_stress_test.dart] [Stress Test: LScope Deep Tree - 500 nested LScope widgets] Resolved deep scope through 500 layers in 0ms
[lib/levit_flutter/status_builder_stress_test.dart] [Stress Test: LStatusBuilder Flood - 500 LStatusBuilder widgets] LStatusBuilder Flood: 500 widgets updated in 9ms
[lib/levit_flutter/lwatch_stress_test.dart] [Stress Test: LWatch Rapid Rebuild - 60fps simulation for 2 seconds] Rapid Rebuild: 1200 builds over 1200 frame updates in 744ms
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collections LxList Mutation Burst - 500k random ops] Performed 500000 mutations in 3295ms (152 ops/ms)
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collections LxMap Bulk Insert - 1M entries] Inserted 1000000 entries in 420ms
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collections LxMap Bulk Insert - 1M entries] Cleared 1000000 entries in 41us
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collections LxMap Update Flood - 100k key updates] Updated 100000 keys in 25ms (100000 notifications)
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collections Collection Computed Propagation] Added 10k items, computed sum=5000050000 in 9ms
[lib/levit_flutter/lscope_stress_test.dart] [Stress Test: LScope Churn - 200 mount/unmount LScope cycles] LScope Churn: 200 mount/unmount cycles in 1034ms (0.2 ops/ms)
[lib/levit_flutter/lview_stress_test.dart] [Stress Test: LView Lifecycle - 100 mount/unmount cycles] LView Lifecycle: 100 mount/unmount cycles in 661ms
[lib/levit_flutter/lview_stress_test.dart] [Stress Test: LView Controller Access - 10k access calls] Controller Access: 10k Levit.find calls in 7ms
[lib/levit_flutter/lwatch_stress_test.dart] [Stress Test: LWatch Subscribe Cleanup - 5000 mount/unmount cycles] LWatch Subscribe Cleanup: 5000 mount/unmount cycles in 6986ms
```
</details>
