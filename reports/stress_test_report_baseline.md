# 🚀 Levit Framework Stress Test Report

> **Generated on:** 2026-01-14

## 📊 Performance Summary

### 🟦 Levit Reactive (Core)

| Scenario | Description | Measured Action | Result |
| :--- | :--- | :--- | :--- |
| Deep Dependency Chain 10,000 nodes deep chain propagates changes correctly | Stresses the notification system by propagating a single change through a 10,000-node deep synchronous dependency chain. | Deep Chain Setup: Created 10000 computed nodes | **50ms** |
| Deep Dependency Chain 10,000 nodes deep chain propagates changes correctly | Stresses the notification system by propagating a single change through a 10,000-node deep synchronous dependency chain. | Deep Chain Propagation: Propagated change through 10000 nodes | **21ms** |
| Collection Bulk Operations LxList with 1,000,000 items and bulk mutations | Measures performance of bulk assignments and rapid random mutations on very large reactive lists. | Large list assign (1M items) | **21ms** |
| Collection Bulk Operations LxList with 1,000,000 items and bulk mutations | Measures performance of bulk assignments and rapid random mutations on very large reactive lists. | 1,000 random mutations on 1M list | **1ms** |
| Collection Bulk Operations LxMap with 100,000 unique keys | Benchmarks insertion and clearing speed for reactive maps with a large number of unique entries. | 100,000 map insertions | **53ms** |
| Collection Bulk Operations LxMap with 100,000 unique keys | Benchmarks insertion and clearing speed for reactive maps with a large number of unique entries. | 100,000 map clear | **80us** |
| Collection Bulk Operations Collection change propagation to computed | Validates that bulk mutations in reactive collections correctly and efficiently propagate to dependent computed values. | Batch add 10,000 items + computed sum | **4ms** |
| Error Recovery Flood System remains stable under flood of errors | Validates stability and recovery when thousands of synchronous errors are triggered simultaneously. | Error Flood: 5000 errors triggered | **16ms** |
| Error Recovery Flood System remains stable under flood of errors | Validates stability and recovery when thousands of synchronous errors are triggered simultaneously. | Recovery Flood: 5000 nodes recovered | **4ms** |
| Massive Fan-Out 100,000 observers on a single Lx source | Measures notification and cleanup overhead when 100,000 individual observers are attached to a single reactive source. | Setup time for 100000 observers | **63ms** |
| Massive Fan-Out 100,000 observers on a single Lx source | Measures notification and cleanup overhead when 100,000 individual observers are attached to a single reactive source. | Notification time for 100000 observers | **15ms** |
| Massive Fan-Out 100,000 observers on a single Lx source | Measures notification and cleanup overhead when 100,000 individual observers are attached to a single reactive source. | Second notification time | **12ms** |
| Massive Fan-Out 100,000 observers on a single Lx source | Measures notification and cleanup overhead when 100,000 individual observers are attached to a single reactive source. | Cleanup time | **15ms** |
| Heavy Payload 1MB Payload Propagation | Measures propagation speed of a large payload (1MB string) through a 100-node reactive chain. | Heavy Payload Setup: Created chain of 100 nodes with 1MB initial payload | **6ms** |
| Heavy Payload 1MB Payload Propagation | Measures propagation speed of a large payload (1MB string) through a 100-node reactive chain. | Heavy Payload Propagation: Propagated 1MB payload through 100 nodes | **10ms** |
| Middleware Overhead 100 Active Middlewares pipeline throughput | Measures the throughput overhead of the middleware pipeline when 100 middlewares (50 filtered, 50 raw) are active. | Middleware Pipeline: Processed 10000 updates with 100 middlewares | **41ms** |
| Rapid Mutation 1,000 rapid updates across 100 sources | Measures propagation speed of a massive volume of individual updates across many parallel sources. | Performed 1000 updates | **29ms** |
| Rapid Mutation Thundering Herd: many reactive nodes reacting to same sources | Tests the scalability of the notification system when a single update triggers thousands of dependent reactive nodes simultaneously. | Thundering herd (100 batches, 1k nodes) | **223us** |
| Diamond Graph Diamond Graph Efficiency (Glitch Freedom) | Measures update efficiency in a "Diamond" dependency graph (A->B,C->D) scaled to a 100x100 grid, ensuring glitch-free propagation. | Diamond Graph Setup: Created 100 diamond layers | **4ms** |
| Diamond Graph Diamond Graph Efficiency (Glitch Freedom) | Measures update efficiency in a "Diamond" dependency graph (A->B,C->D) scaled to a 100x100 grid, ensuring glitch-free propagation. | Diamond Graph Update: Propagated change through 100 layers | **4ms** |
| Memory Churn & Lifecycle Repeatedly create and dispose 10,000 reactive objects | Stresses the memory and lifecycle management by iteratively creating and specifically disposing 10,000 reactive nodes. | Completed 10000 lifecycle iterations | **10000** |
| Memory Churn & Lifecycle Churn with cross-dependencies | Tests lifecycle stability and memory cleanup when complex dependency subgraphs are rapidly created and disposed. | Completed 5000 cross-dependency lifecycle iterations | **5000** |
| Dynamic Graph Churn Subscription graph changes rapidly under load | Stresses subscriber management by rapidly reconfiguring the dependency graph under load. | Dynamic Graph Churn: 10000 iterations with 1000 nodes | **7251ms** |

### 🟨 Levit DI (Dependency Injection)

| Scenario | Description | Measured Action | Result |
| :--- | :--- | :--- | :--- |
| Deep Scoping Deeply Nested Scopes (1,000 levels) | Measures the manual setup cost and memory overhead of creating a massive scope hierarchy. | Created 1000 nested scopes | **3ms** |
| Deep Scoping Deeply Nested Scopes (1,000 levels) | Measures the manual setup cost and memory overhead of creating a massive scope hierarchy. | Resolved local | **2ms** |
| Deep Scoping Deep Traversal Resolution | Benchmarks the resolution speed when a dependency must be found by traversing multiple levels of parent scopes. | Resolved root dependency through 1000 layers | **1ms** |
| Concurrent Access Concurrent Async Resolution (10,000 futures) | Validates thread-safety and resolution consistency when thousands of concurrent async requests hit the same provider. | Resolved 10000 concurrent requests | **251ms** |
| DI Registration Massive Registration & Resolution (100,000 services) | Measures basic registration and resolution speed for a massive number of unique services in the root container. | Registered 100000 services | **90ms** |
| DI Registration Massive Registration & Resolution (100,000 services) | Measures basic registration and resolution speed for a massive number of unique services in the root container. | Resolved 100000 services | **49ms** |
| Provider Shadowing Resolution remains efficient with deep shadowing | Benchmarks resolution efficiency in deeply nested scopes with local overrides. | Deep Shadowing Setup: Created 1000 nested scopes | **3ms** |
| Provider Shadowing Resolution remains efficient with deep shadowing | Benchmarks resolution efficiency in deeply nested scopes with local overrides. | Deep Shadowing Resolution: Performed 10000 resolutions at depth 1000 | **8ms** |
| Provider Shadowing Resolving root dependency through many layers of shadowing | Measures performance of root dependency lookups traversing many nested scope layers. | Root Resolution: Resolved through 1000 layers 10000 times | **3ms** |
| Memory Churn & Lifecycle Put/Delete Cycles (1,000,000 iterations) | Stresses the DI container and lifecycle hooks with continuous massive registration and deletion cycles. | Performed 1000000 put/delete cycles | **462ms** |

### 🟪 Levit Flutter (UI Binding)

| Scenario | Description | Measured Action | Result |
| :--- | :--- | :--- | :--- |
| LWatch Fan-In One LWatch observing 2,000 sources | Tests a single LWatch widget dependent on 2,000 sources, measuring rebuild performance for both single and batch updates. | Initial build with 2000 dependencies | **17ms** |
| LWatch Fan-In One LWatch observing 2,000 sources | Tests a single LWatch widget dependent on 2,000 sources, measuring rebuild performance for both single and batch updates. | Update time for 2000 dependencies | **5ms** |
| LWatch Fan-In One LWatch observing 2,000 sources | Tests a single LWatch widget dependent on 2,000 sources, measuring rebuild performance for both single and batch updates. | Batch update (100) time | **2ms** |
| LStatusBuilder State Switching | Benchmarks the performance of 2,000 LStatusBuilder widgets switching through all possible async states. | LStatusBuilder Setup: Built 2000 widgets (Idle) | **263ms** |
| LStatusBuilder State Switching | Benchmarks the performance of 2,000 LStatusBuilder widgets switching through all possible async states. | LStatusBuilder Switch: Switched 2000 widgets to Waiting | **23ms** |
| LStatusBuilder State Switching | Benchmarks the performance of 2,000 LStatusBuilder widgets switching through all possible async states. | LStatusBuilder Switch: Switched 2000 widgets to Success | **12ms** |
| LStatusBuilder State Switching | Benchmarks the performance of 2,000 LStatusBuilder widgets switching through all possible async states. | LStatusBuilder Switch: Switched 2000 widgets to Error | **10ms** |
| LStatusBuilder Flood Switching 10,000 status builders in a single frame | Measures the UI overhead of switching 10,000 LStatusBuilder widgets between states simultaneously. | LStatusBuilder Flood (Success): 10,000 widgets switched | **32ms** |
| LStatusBuilder Flood Switching 10,000 status builders in a single frame | Measures the UI overhead of switching 10,000 LStatusBuilder widgets between states simultaneously. | LStatusBuilder Flood (Error): 10,000 widgets switched | **19ms** |
| Deep Tree Scoping Resolve controller through 1,000 layers | Measures the time to resolve a controller from a deep widget tree, testing LScope traversal efficiency. | Resolved deep scope through 1000 layers | **23ms** |
| LView Churn Rapidly mount and unmount LViews | Tests the lifecycle efficiency of LView and its controllers by rapidly mounting and unmounting 50,000 instances. | Performed 500 view churn cycles (100 views each) | **747ms** |
| LWatch Fan-Out 10,000 observers on a single Lx source | Measures notification overhead when 10,000 LWatch widgets observe and react to a single shared source change. | Setup time for 10000 LWatch widgets | **1806ms** |
| LWatch Fan-Out 10,000 observers on a single Lx source | Measures notification overhead when 10,000 LWatch widgets observe and react to a single shared source change. | Notification time for 10000 LWatch widgets | **656ms** |
| LWatch Fan-Out 10,000 observers on a single Lx source | Measures notification overhead when 10,000 LWatch widgets observe and react to a single shared source change. | Second notification time | **583ms** |

## 📜 Raw Execution Logs
<details>
<summary>Click to view full logs</summary>

```text
[lib/levit_reactive/deep_chain_stress_test.dart] [Stress Test: Deep Dependency Chain 10,000 nodes deep chain propagates changes correctly] Deep Chain Setup: Created 10000 computed nodes in 50ms
[lib/levit_reactive/deep_chain_stress_test.dart] [Stress Test: Deep Dependency Chain 10,000 nodes deep chain propagates changes correctly] Deep Chain Propagation: Propagated change through 10000 nodes in 21ms
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations LxList with 1,000,000 items and bulk mutations] Large list assign (1M items) took 21ms
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations LxList with 1,000,000 items and bulk mutations] 1,000 random mutations on 1M list took 1ms
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations LxMap with 100,000 unique keys] 100,000 map insertions took 53ms
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations LxMap with 100,000 unique keys] 100,000 map clear took 80us
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations Collection change propagation to computed] Batch add 10,000 items + computed sum took 4ms
[lib/levit_reactive/error_recovery_flood_stress_test.dart] [Stress Test: Error Recovery Flood System remains stable under flood of errors] Error Flood: 5000 errors triggered in 16ms
[lib/levit_reactive/error_recovery_flood_stress_test.dart] [Stress Test: Error Recovery Flood System remains stable under flood of errors] Recovery Flood: 5000 nodes recovered in 4ms
[lib/levit_reactive/fan_out_stress_test.dart] [Stress Test: Massive Fan-Out 100,000 observers on a single Lx source] Setup time for 100000 observers: 63ms
[lib/levit_reactive/fan_out_stress_test.dart] [Stress Test: Massive Fan-Out 100,000 observers on a single Lx source] Notification time for 100000 observers: 15ms
[lib/levit_reactive/fan_out_stress_test.dart] [Stress Test: Massive Fan-Out 100,000 observers on a single Lx source] Second notification time: 12ms
[lib/levit_reactive/fan_out_stress_test.dart] [Stress Test: Massive Fan-Out 100,000 observers on a single Lx source] Cleanup time: 15ms
[lib/levit_reactive/heavy_payload_stress_test.dart] [Stress Test: Heavy Payload 1MB Payload Propagation] Heavy Payload Setup: Created chain of 100 nodes with 1MB initial payload in 6ms
[lib/levit_reactive/heavy_payload_stress_test.dart] [Stress Test: Heavy Payload 1MB Payload Propagation] Heavy Payload Propagation: Propagated 1MB payload through 100 nodes in 10ms
[lib/levit_reactive/middleware_overhead_stress_test.dart] [Stress Test: Middleware Overhead 100 Active Middlewares pipeline throughput] Middleware Pipeline: Processed 10000 updates with 100 middlewares in 41ms
[lib/levit_reactive/rapid_mutation_stress_test.dart] [Stress Test: Rapid Mutation 1,000 rapid updates across 100 sources] Performed 1000 updates in 29ms
[lib/levit_reactive/rapid_mutation_stress_test.dart] [Stress Test: Rapid Mutation Thundering Herd: many reactive nodes reacting to same sources] Thundering herd (100 batches, 1k nodes) took 223us
[lib/levit_reactive/diamond_graph_stress_test.dart] [Stress Test: Diamond Graph Diamond Graph Efficiency (Glitch Freedom)] Diamond Graph Setup: Created 100 diamond layers in 4ms
[lib/levit_reactive/diamond_graph_stress_test.dart] [Stress Test: Diamond Graph Diamond Graph Efficiency (Glitch Freedom)] Diamond Graph Update: Propagated change through 100 layers in 4ms
[lib/levit_reactive/memory_churn_stress_test.dart] [Stress Test: Memory Churn & Lifecycle Repeatedly create and dispose 10,000 reactive objects] Completed 10000 lifecycle iterations
[lib/levit_reactive/memory_churn_stress_test.dart] [Stress Test: Memory Churn & Lifecycle Churn with cross-dependencies] Completed 5000 cross-dependency lifecycle iterations
[lib/levit_scope/deep_scope_stress_test.dart] [Stress Test: Deep Scoping Deeply Nested Scopes (1,000 levels)] Created 1000 nested scopes in 3ms
[lib/levit_scope/deep_scope_stress_test.dart] [Stress Test: Deep Scoping Deeply Nested Scopes (1,000 levels)] Resolved local in deep scope in 2ms
[lib/levit_scope/deep_scope_stress_test.dart] [Stress Test: Deep Scoping Deep Traversal Resolution] Resolved root dependency through 1000 layers in 1ms
[lib/levit_scope/concurrent_access_stress_test.dart] [Stress Test: Concurrent Access Concurrent Async Resolution (10,000 futures)] Resolved 10000 concurrent requests in 251ms
[lib/levit_scope/registration_stress_test.dart] [Stress Test: DI Registration Massive Registration & Resolution (100,000 services)] Registered 100000 services in 90ms
[lib/levit_scope/registration_stress_test.dart] [Stress Test: DI Registration Massive Registration & Resolution (100,000 services)] Resolved 100000 services in 49ms
[lib/levit_scope/provider_shadowing_stress_test.dart] [Stress Test: Provider Shadowing Resolution remains efficient with deep shadowing] Deep Shadowing Setup: Created 1000 nested scopes in 3ms
[lib/levit_scope/provider_shadowing_stress_test.dart] [Stress Test: Provider Shadowing Resolution remains efficient with deep shadowing] Deep Shadowing Resolution: Performed 10000 resolutions at depth 1000 in 8ms
[lib/levit_scope/provider_shadowing_stress_test.dart] [Stress Test: Provider Shadowing Resolving root dependency through many layers of shadowing] Root Resolution: Resolved through 1000 layers 10000 times in 3ms
[lib/levit_scope/churn_stress_test.dart] [Stress Test: Memory Churn & Lifecycle Put/Delete Cycles (1,000,000 iterations)] Performed 1000000 put/delete cycles in 462ms
[lib/levit_flutter/massive_fan_in_stress_test.dart] [Stress Test: LWatch Fan-In One LWatch observing 2,000 sources] Initial build with 2000 dependencies: 17ms
[lib/levit_flutter/massive_fan_in_stress_test.dart] [Stress Test: LWatch Fan-In One LWatch observing 2,000 sources] Update time for 2000 dependencies: 5ms
[lib/levit_flutter/massive_fan_in_stress_test.dart] [Stress Test: LWatch Fan-In One LWatch observing 2,000 sources] Batch update (100) time: 2ms
[lib/levit_flutter/status_builder_stress_test.dart] [Stress Test: LStatusBuilder State Switching] LStatusBuilder Setup: Built 2000 widgets (Idle) in 263ms
[lib/levit_flutter/status_builder_stress_test.dart] [Stress Test: LStatusBuilder State Switching] LStatusBuilder Switch: Switched 2000 widgets to Waiting in 23ms
[lib/levit_flutter/status_builder_stress_test.dart] [Stress Test: LStatusBuilder State Switching] LStatusBuilder Switch: Switched 2000 widgets to Success in 12ms
[lib/levit_flutter/status_builder_stress_test.dart] [Stress Test: LStatusBuilder State Switching] LStatusBuilder Switch: Switched 2000 widgets to Error in 10ms
[lib/levit_flutter/status_builder_flood_stress_test.dart] [Stress Test: LStatusBuilder Flood Switching 10,000 status builders in a single frame] LStatusBuilder Flood (Success): 10,000 widgets switched in 32ms
[lib/levit_flutter/status_builder_flood_stress_test.dart] [Stress Test: LStatusBuilder Flood Switching 10,000 status builders in a single frame] LStatusBuilder Flood (Error): 10,000 widgets switched in 19ms
[lib/levit_flutter/deep_tree_scope_stress_test.dart] [Stress Test: Deep Tree Scoping Resolve controller through 1,000 layers] Resolved deep scope through 1000 layers in 23ms
[lib/levit_flutter/view_churn_stress_test.dart] [Stress Test: LView Churn Rapidly mount and unmount LViews] Performed 500 view churn cycles (100 views each) in 747ms
[lib/levit_flutter/massive_fan_out_stress_test.dart] [Stress Test: LWatch Fan-Out 10,000 observers on a single Lx source] Setup time for 10000 LWatch widgets: 1806ms
[lib/levit_flutter/massive_fan_out_stress_test.dart] [Stress Test: LWatch Fan-Out 10,000 observers on a single Lx source] Notification time for 10000 LWatch widgets: 656ms
[lib/levit_flutter/massive_fan_out_stress_test.dart] [Stress Test: LWatch Fan-Out 10,000 observers on a single Lx source] Second notification time: 583ms
[lib/levit_reactive/dynamic_graph_churn_stress_test.dart] [Stress Test: Dynamic Graph Churn Subscription graph changes rapidly under load] Dynamic Graph Churn: 10000 iterations with 1000 nodes in 7251ms
```
</details>
