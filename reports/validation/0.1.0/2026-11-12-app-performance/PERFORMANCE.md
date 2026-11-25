# Computed and grid performance follow-up — 2026-11-12

Computed optimizations are implemented and validated; the unchanged comparison
has been repeated. Grid measurements remain variable and overall performance
sign-off stays open. This report does not certify or publish a new release
candidate. The previous certificate continues to apply only to its archived source.

## Matched inputs

The reference is the checkout at the start of this task, preserved at
`/private/tmp/levit-20261112-before-vdalnd4n`. This measures the effect of these
fixes on the corrected methodology-2 dashboard. It is **not** a new comparison
against `539f130`; the older reference-comparison evidence remains separate.
The pasted report had an unrecorded source identity and is not used as a matched
before result.

[Native host fingerprints](native-host-source.json) also confirm identical
window/activity-policy sources and assets. Both revisions use the real dashboard and sidebar, the existing benchmark
implementations, five warmups, 50 samples, normal pacing and consumer verification.
Each revision runs in its own process in before → after → after → before order.
The driver checks identical benchmark Dart sources and dependency locks, stamps
source digests, records executable/AOT hashes, and rejects changed viewport or
refresh rate. All accepted runs so far use 800×600 logical pixels, 2× scale,
120 Hz, Dart 3.12.2 and Flutter 3.44.8 on the same Mac. Monitor attachment is off.
Builds, tests and CPU profiling do not overlap latency measurements.

[Resolved package paths](resolved-local-dependencies.json) verify that the
reference actually imports its own preserved runtime. No workload was switched to
`staticDeps`, and no item count, viewport,
key behavior, iteration body, validation or cleanup was reduced.

## Runtime changes

[The patch](runtime-change.patch) changes only `computed.dart` in runtime code:

- Verify each dependency read against the last successful dependency order.
  Exact matches reuse subscriptions and avoid reconstructing dependency sets.
  Reordered, repeated, new or removed reads fall back to normal capture.
- Keep graph-depth recalculation even when membership is unchanged. Cache and
  tracker references are released on inactivity/closure and after failures.
- Avoid temporary sets and repeated scans when reconciling small or unchanged
  graphs. Exact membership is still checked; a hash match alone is never enough.
- Keep ordinary computed reads compact and keep optional graph-diagnostic capture
  in a separate helper. VM inlining hints concern these general runtime paths,
  with no benchmark name, graph size or workload-specific switch.
- Release pooled trackers in `finally`, including computation/comparator/
  notification errors. A listener that closes a computed during eager publication
  cannot cause it to resubscribe afterward.

These paths are used by ordinary derived application state. The changes are not
an across-the-board application speed claim: I/O, rasterization and Flutter grid
layout are unaffected. Public behavior and ownership contracts are unchanged.

## Profile evidence

Before the fix, dependency reconciliation accounts for 48.8% of inclusive CPU
samples in fan-in and 51.8% in fan-out. Set construction and hash-table iteration
are prominent costs. The retained optimization removes that repeated work from
verified unchanged graphs. Inclusive percentages overlap and must not be summed.

The chain follow-up matters: the first implementation improved fan-in/fan-out but
slowed the unchanged chain by 13–16% in isolated release runs. The compact getter
removes that regression: two isolated pairs show 3–5% lower chain medians, with
similar vanilla timings. A plain read-path rewrite and a recomputation inlining
hint were also tried and not retained. [Iteration provenance](iterations.json)
keeps these unfavorable results and separates them from the final implementation.

Grid profiling shows shared Flutter layout dominating both implementations:
`flushLayout` is about 57% of sampled CPU in the starting Levit and vanilla runs.
Computed reconciliation is not on the grid path. Scope bridging is about 1–2%
of sampled grid CPU, far smaller than the originally reported timing gap.

Raw profiles are losslessly compressed under `profiles/`; the collector source
is [retained here](profile_collector.dart.txt). Profiling repeats existing fixture
bodies for eight seconds. Logic profiling omits normal inter-sample idle periods
to gather CPU samples, so **profile-loop throughput is not reported as latency
improvement**. Allocation snapshots are retained for inspection, not presented
as per-operation allocation counts.

## Final repeated release results

All **240 cases, 12,000 wall samples and 4,000 matched engine frames** pass.
The additional final grid selection passes **20 cases and 1,000 matched frames**.

| Workload / metric | Before 1 → After 1 (µs) | Before 2 → After 2 (µs) | Paired median changes |
|---|---:|---:|---:|
| Fan In Update / wallUs | 527.5 → 193.5 | 521 → 94 | -63.3%, -82.0% |
| Fan Out Update / wallUs | 1043 → 649.5 | 827 → 650 | -37.7%, -21.4% |
| Computed Chain (Deep Propagation) / wallUs | 27107 → 25003 | 26508.5 → 21207 | -7.8%, -20.0% |
| Dynamic Grid Churn (UI) / buildUs | 4398 → 4301 | 4826 → 4717 | -2.2%, -2.3% |

Negative changes mean lower elapsed time. The second pair ran after → before.
The fan-in/fan-out reductions repeat in both pairs; the chain regression is removed.
The small full-suite grid difference is not evidence of a grid-specific fix.

[Full results for every framework and workload](release-final/summary.md) include
all raw runs, per-process p50/p95 and source/AOT fingerprints. The measured
Dart/manifests input digests are before `05fbe138c82c17a7f2a2342a43dfbd03fcf3b1ae5e178502f08bc6127cb6b2d8` and
after `cecdfff2b8d212e13ee5a248bd9c652c1db6e9c697297d7ce24ec3a135b149dd`; [the manifests](release-final/inputs.json)
differ only at `packages/core/levit_reactive/lib/src/computed.dart`.

**Overall performance sign-off stays open.** Other full-suite signals are
higher list-build medians (+24% / +47%), progress-bar build medians
(+17% / +14%) and warm-root DI medians (+23% / +8%). These paths were not
changed here, controls also vary, and causation has not been established.
They are retained as follow-up signals, not silently labeled improvements.
This closes the targeted computed work, not a blanket performance or release certification.

## Grid interpretation

The initial full-suite pairs showed higher optimized grid medians (+5.5% and
+26.4%). Isolating exactly the same grid through normal dashboard selection
reversed the direction (−5.1% and −10.7%); vanilla also became faster. Isolation
preserves all five frameworks, their relative order, viewport, keys, warmups,
samples, frame capture and cleanup. Only the surrounding workload history changes.

These conflicting directions do not establish a grid-specific runtime regression
or a grid fix. No grid-specific patch is retained. Grid remains layout intensive,
and occasional frames exceed the 8.33 ms interval on this 120 Hz display. Build
and raster costs are whole-frame measurements, not isolated framework CPU or
counts of dropped frames. Final full-suite grid-build medians are 2.2% lower in both pairs, but final
isolated medians change by **+58.9% and −32.7%**. This variability remains too large
to claim a grid optimization. [Final grid data](grid-final/summary.md) retains
build, raster and update-to-frame-end measurements separately.

## Application and correctness validation

The new mounted catalog regression uses the actual `AsyncCatalogApp`, its default
repository latency and route-owned controller. It checks pagination, search,
stable-handle refresh, optimistic save/rollback, and unmount during a pending
request, then awaits scope disposal. This demonstrates preserved application
behavior, not a measured catalog end-to-end speedup.

The computed regression covers changing/reordered/repeated/removed dependencies,
small and large graphs, diagnostics on/off, reactivation, graph-depth changes,
failed capture and closure during eager publication. Existing tests cover nested
observers, stack-trace preservation, batching and asynchronous cleanup.

Final validation passes: formatting, fatal-info analysis and aggregate CI;
**6,767/6,767 covered lines across all 11 packages**; all 104 benchmark tests and
38 stress tests; browser runtime compilation, the catalog release web build, and
the native release build. Exact commands and exit statuses are in
[checks-final/results.json](checks-final/results.json). Both normal interactive
profile and release apps have also been [rebuilt with the measured source identity](checks-final/interactive-builds.json).
The [final source check](final-source-check.json) confirms that all measured inputs
and the retained runtime snapshot still match the working tree.

## Reproduction and limits

From the repository root:

```sh
python3 scripts/compare_app_performance.py \
  --before-root /private/tmp/levit-20261112-before-vdalnd4n \
  --after-root "$PWD" --output /tmp/levit-repeat \
  --flutter /Users/atoumbre/devs/flutter/bin/flutter
python3 scripts/summarize_app_performance.py /tmp/levit-repeat
```

Use `--grid-only` or `--chain-only` for the separate diagnostic selections.
They do not replace the full comparison. Report per-process medians and paired
changes; 50 consecutive samples do not constitute 50 independent experiments.
The evidence covers one machine and these workloads, with diagnostics off for
latency comparisons. No overall framework ranking, universal application
speedup, fresh `539f130` certification or publication is claimed.
