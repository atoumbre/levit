# Collection performance follow-up

The comparison uses Dart 3.12.2 and Flutter 3.44.8 on macOS arm64. The release reference is 539f130. The frozen pre-redesign checkout captures the cost of replacing families and introducing address observation. The November 14 candidate before these fixes is included in the focused comparison. [Measured sources, locks and executables](inputs.json) · [Candidate source changes](source-delta.json)

List shifts and subscription churn beat both baselines in all eight paired focused runs. The native workload independently showed faster computed fan-out with diagnostics off. Overall performance sign-off remains open for the slower results described below.

## Focused AOT results

Each cell is the median of eight process medians, in microseconds per 256 operations. Each process discards two warmups and measures nine samples of the unchanged 128-address workload. Four rotated execution orders and their reverses balance launch position. The final column gives the number of paired rounds in which the fix was faster than the frozen pre-redesign runtime. Lower is faster. [Raw samples and evaluation counts](addresses-raw.json) · [Per-process medians](addresses-summary.json)

| Workload | 539f130 | Pre-redesign | Prior candidate | Fixed candidate | Δ vs 539f130 | Δ vs pre-redesign | Δ vs prior candidate | Wins vs pre-redesign |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Sparse map key | 7,411.5 | 3,310.0 | 107.0 | 72.0 | -99.0% | -97.8% | -32.7% | 8/8 |
| Sparse list index | 6,962.0 | 2,957.5 | 88.0 | 56.0 | -99.2% | -98.1% | -36.4% | 8/8 |
| Insert and remove at index 32 | 14,426.0 | 6,089.5 | 10,748.5 | 4,153.5 | -71.2% | -31.8% | -61.4% | 8/8 |
| Two-key map write | 7,439.0 | 3,338.5 | 2,249.5 | 1,564.0 | -79.0% | -53.2% | -30.5% | 8/8 |
| Subscribe and close | 139.5 | 200.5 | 675.0 | 129.0 | -7.5% | -35.7% | -80.9% | 8/8 |

Each sparse case delivered 256 evaluations, down from 32,768 on both pre-collection baselines. Shifts delivered 49,152, down from 65,536. Bulk writes delivered 512, down from 32,768. All four runtimes executed 256 subscribe/close cycles per churn sample. The old reference exposed synchronous void close. Its isolated compilation overlay widens the return annotation and uses explicit null for the early return. This preserves synchronous cleanup and gives the byte-identical benchmark the same await at each call site. The other builds use their original package APIs. [Reference patch](reference-close-types.patch) · [Timed workload](../../../../packages/core/levit_reactive/benchmark/collection_addresses.dart)

## Profiles and runtime changes

- **Insert and remove at index 32.** The original profile showed repeated address resolution, notification sorting and per-mutation traversal allocations. The sampler completed 193 → 215 workload iterations in its 2.5-second windows (1,948 and 991 CPU samples). [Before](shift-before.json) · [After](shift-after.json)
- **Subscribe and close.** Name formatting alone accounted for 466 self samples on the original candidate. The runtime now builds diagnostic labels on demand and avoids the asynchronous close machinery for an empty internal channel. The sampler completed 3,776 → 16,652 workload iterations in its 2.5-second windows (1,917 and 1,943 CPU samples). [Before](churn-before.json) · [After](churn-after.json)

The collection caches its observed-channel list until a subscription changes. A list range operation limits publication to affected positions. Repeated computed reads verify collection, address and read kind against their previously captured order. The first differing read falls back to dynamic capture. Single-observer graphs avoid allocating a dependency set. Batches reuse queue storage, release delivered references, preserve depth ordering, and clear pending flags after exceptions. The VM-service samples explain where CPU time went. The separate AOT runs provide the reported timings. [Profiler source](cpu_profile.dart.txt)

An active stream or disposal hook still takes the awaited cleanup path. The collection reserves retirement before invoking a hook that could reenter parent closure. The tests cover aggregation across active and retiring entries, delayed activation, a failed batch with over 4,000 notifications, and removal of a dynamically replaced address. The catalog also confirms a favorite-only edit rebuilt one of six mounted rows. [Regression tests](../../../../packages/core/levit_reactive/test/collections/entry_contract_test.dart) · [Mounted app tests](catalog.log)

## Native application matrix

Each cell below shows the candidate change against **pre-redesign / 539f130**. Each revision ran twice per mode and diagnostics setting, in opposite revision order. Each process contains three rounds per workload. For these paired comparisons each process gets one vote. Logic timings include delivery and the event-loop turn. A post-timing flush verifies that all admitted monitor events arrived. The body checkpoint can occur at different points in each monitor pipeline and is unsuitable for cross-version delivery comparisons. The frame row is measured frame cadence. Build and raster durations and all paired changes are recorded separately. [Per-process comparisons](native-pairs.json) · [Original driver output](native/performance-summary.json) · [Run log](measurement.log)

| Workload | Profile off | Profile on | Release off | Release on |
| --- | ---: | ---: | ---: | ---: |
| notify\_10000 | +0.0% / -0.2% | +0.7% / -6.9% | +1.7% / -0.2% | +2.9% / +0.5% |
| fanout\_128\_x\_100 | -36.5% / -75.1% | +3.1% / -9.9% | -37.3% / -74.5% | +0.6% / -4.9% |
| scope\_lifetime\_100 | +0.5% / -1.5% | +0.2% / +6.1% | +0.6% / -0.9% | +3.3% / +4.0% |
| tasks\_100 | +0.1% / +3.6% | +0.0% / -1.8% | +1.0% / +9.3% | +2.5% / +1.1% |
| list\_1000\_frame | +0.1% / +0.0% | -0.0% / -0.0% | -0.2% / +0.1% | -0.0% / +0.1% |

Across 24 accepted native processes the driver validated 12,960 observed timings, including 4,320 individual Flutter frames. Median frame cadence stayed within 0.2% of pre-redesign in every setting. The unmonitored release fan-out dropped from 1,182 to 741 µs per 12,800 computed deliveries. The same comparison with monitoring enabled measured 58,517 and 58,847 µs (+0.6%). These are workload-specific results.

Overall performance sign-off remains open. The release task workload with diagnostics off took 174 µs per 100 tasks, up from 159.25 µs on 539f130 (+9.3%, slower in both launches) and 172.25 µs pre-redesign (+1.0%). Monitored release scope teardown took 4,355 µs per 100 lifetimes, up 3.3% against pre-redesign and 4.0% against 539f130. Monitored profile fan-out took 3.1% longer than pre-redesign in aggregate and was slower in both launch pairs. This matrix measures end-to-end delivery and cannot attribute those differences to list shifts or channel retirement. [Per-launch results](native-pairs.json)

The first 24-process attempt was rejected for mixed geometry. Two launches used 800 × 600 physical pixels at 1× and 60 Hz. The full matrix was repeated with a fixed geometry check. All 24 launches in the accepted matrix used 1600 × 1200 pixels at 2× and 120 Hz on display 1. [Rejected run](first-measurement.log) · [Geometry check and reproduction](REPRODUCE.md)

The previous reference profile executable printed the interactive profiler’s ready marker. Rebuilding from its release-performance entrypoint corrected the input. Both native baselines ran the same workload source, and the driver checked reference labels, geometry, diagnostics teardown, nonzero samples and actual frame IDs. [Reference build](reference-profile-build.log) · [Measurement identities](inputs.json)

## Validation

Aggregate CI passed, including fatal-info analysis and the Dart and Flutter suites. The benchmark harness passed 119 tests, the stress suite passed 38, and the catalog passed five. The coverage gate passed 7,099/7,099 lines across 11 packages. The source manifest covers the same 922 paths as the preceding candidate and differs in four runtime files and one test file. [CI](ci.log) · [Coverage](coverage.log) · [Benchmark harness](benchmark-tests.log) · [Stress suite](stress.log) · [Source manifest delta](source-delta.json)
