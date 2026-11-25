# Computed tracking modes — 2026-11-12

Static tracking is not uniformly faster. With each workload isolated in its own
process, static reduces fan-in, diamond and batch medians in all four matched
pairs. Fan-out changes direction between pairs. The observed deep chain is
consistently slower in static mode; async is also slightly slower in these runs.
These are timing observations on this machine, not a universal mode ranking.

## Controlled inputs and limits

- Six existing app computed implementations; only `staticDeps` changes. Work
  sizes, compute functions, subscriptions, verification, warmups, sample pacing
  and awaited cleanup remain unchanged. See [the exact fixture diff](workload-options.patch).
- All six graphs have fixed dependencies, so both modes are semantically valid.
  Rapid mutation, DI and UI fixtures do not use computed tracking and are excluded.
- Same release AOT binary for static/dynamic within each experiment. Diagnostics
  are unattached. Flutter 3.44.8 / Dart 3.12.2, macOS 26.6.2, 8 logical processors,
  800×600 logical viewport at 2×, 120 Hz. No builds, tests or CPU profiling ran
  concurrently with measured app processes.
- Background browser/simulator activity was observed before measurement. This
  was not a fully idle machine. Paired results and all raw samples are retained;
  small differences and variable tails should not be treated as settled results.
- Every process uses the normal runner: production sizes, five warmups, 50
  measured samples and 10ms idle between samples. Timing includes required work
  and delivery; setup, verification and awaited teardown are outside timing.
- Each experiment has four adjacent static/dynamic pairs. Mode order is D→S,
  S→D, S→D, D→S. Suite order is forward, reverse, forward, reverse by pair.
  Each isolated process has only one workload, so its workload-order flag is
  immaterial; mode order remains balanced.
- Each table cell is the median of four independent process p50s or p95s.
  p95 uses nearest rank within each 50-sample process. Change is
  `(static / dynamic − 1) × 100`; negative means less time in static mode.
  Paired changes are also reported to reveal variability. Samples are not pooled
  as 200 independent trials and no significance/confidence interval is claimed.
- The suite and isolated comparisons are separate experiments. The second build
  adds an optional workload selector; the six fixture implementations are
  identical. Do not compare their absolute timings as a revision speedup.

## Isolated workloads: p50

Each workload starts in a fresh process to remove prior-workload history. Four
processes per mode per workload: **48 processes, 48 valid cases, 2,400 samples**.

| Workload | Dynamic (µs) | Static (µs) | Static change | Four paired changes |
|---|---:|---:|---:|---|
| Diamond (10,000 writes) | 1,913.25 | 1,403.75 | -26.6% | -6.3%, -38.2%, -23.9%, -21.9% |
| Fan-out (1,000 outputs) | 432.75 | 344.75 | -20.3% | -46.5%, -54.1%, +9.4%, +11.8% |
| Fan-in (1,000 inputs) | 214.25 | 78.25 | -63.5% | -67.7%, -55.7%, -82.3%, -30.5% |
| Async (100 awaited updates) | 2,799.00 | 2,974.50 | +6.3% | +9.7%, +1.6%, +1.7%, +3.1% |
| Batch (1,000 writes / 100 sources) | 111.75 | 99.00 | -11.4% | -8.2%, -14.8%, -7.5%, -37.2% |
| Chain (1,000 levels × 1,000 writes) | 21,950.00 | 25,945.50 | +18.2% | +16.1%, +9.2%, +22.6%, +17.8% |

## Isolated workloads: p95

These are medians of per-process p95s, not a pooled p95. With only 50 samples per
process and background activity, tail estimates are particularly variable.

| Workload | Dynamic (µs) | Static (µs) | Static change | Four paired changes |
|---|---:|---:|---:|---|
| Diamond (10,000 writes) | 3,681.50 | 2,271.50 | -38.3% | -5.6%, -62.2%, -32.6%, -24.0% |
| Fan-out (1,000 outputs) | 983.00 | 726.00 | -26.1% | -69.1%, -58.3%, +90.0%, -11.1% |
| Fan-in (1,000 inputs) | 497.50 | 165.00 | -66.8% | -64.6%, -61.5%, -75.7%, -63.8% |
| Async (100 awaited updates) | 4,354.50 | 5,098.50 | +17.1% | +8.2%, +53.7%, +24.9%, -31.0% |
| Batch (1,000 writes / 100 sources) | 298.50 | 180.50 | -39.5% | -29.9%, -60.9%, -14.2%, -6.9% |
| Chain (1,000 levels × 1,000 writes) | 27,272.00 | 27,007.00 | -1.0% | +3.8%, -1.3%, -0.8%, -1.1% |

## Six-workload suite: p50

The initial comparison runs all six workloads in one process, in forward or
reverse order. It is retained in full: **8 processes, 48 valid cases, 2,400
samples**. Several mode differences reverse sign across pairs. The strong
workload-order association motivated isolation; it does not prove a specific
allocator, scheduler or tracker-pool cause.

| Workload | Dynamic (µs) | Static (µs) | Static change | Four paired changes |
|---|---:|---:|---:|---|
| Diamond (10,000 writes) | 1,749.75 | 1,300.75 | -25.7% | +13.5%, -39.1%, +12.6%, -59.3% |
| Fan-out (1,000 outputs) | 381.50 | 211.50 | -44.6% | -75.1%, -45.6%, -37.2%, +15.8% |
| Fan-in (1,000 inputs) | 165.00 | 79.75 | -51.7% | +8.5%, -82.8%, +3.8%, -61.5% |
| Async (100 awaited updates) | 2,675.25 | 3,369.50 | +26.0% | +14.6%, +1.7%, +140.6%, +1.3% |
| Batch (1,000 writes / 100 sources) | 88.00 | 65.50 | -25.6% | -15.1%, -45.3%, +49.0%, -33.5% |
| Chain (1,000 levels × 1,000 writes) | 24,678.75 | 25,926.50 | +5.1% | +0.8%, +11.4%, -1.6%, +11.7% |

## Six-workload suite: p95

| Workload | Dynamic (µs) | Static (µs) | Static change | Four paired changes |
|---|---:|---:|---:|---|
| Diamond (10,000 writes) | 3,940.00 | 2,719.00 | -31.0% | +25.0%, -32.5%, -29.3%, -39.4% |
| Fan-out (1,000 outputs) | 995.00 | 482.50 | -51.5% | -61.9%, -57.5%, +29.4%, -34.0% |
| Fan-in (1,000 inputs) | 317.00 | 209.00 | -34.1% | -21.4%, -55.6%, +15.8%, -87.0% |
| Async (100 awaited updates) | 4,146.50 | 5,943.00 | +43.3% | +36.7%, -37.5%, +72.4%, +50.1% |
| Batch (1,000 writes / 100 sources) | 196.00 | 195.50 | -0.3% | -7.9%, -0.5%, +81.0%, -12.9% |
| Chain (1,000 levels × 1,000 writes) | 27,274.00 | 27,287.50 | +0.0% | +3.8%, +0.5%, -13.6%, -3.5% |

## Interpretation

- **Fan-in:** strongest static benefit in the isolated experiment, with p50
  lower by 30–82% across pairs and p95 lower in every pair. Static skips checking
  all dependency reads and refreshing graph depth on subsequent evaluations;
  summing all 1,000 inputs still occurs. The suite's mixed pair results show that
  the exact gain depends on workload history/environment.
- **Diamond:** isolated p50 is lower in all four pairs (6–38%). Static eliminates
  repeated dependency-tracking checks for the observed result. The initial suite
  has two pairs in each direction, so the isolated percentage is not an app-wide
  improvement claim.
- **Batch:** isolated p50 is lower in all four pairs (8–37%). Batching already
  collapses recomputation, so the tracking-mode change affects only part of the
  timed work. Native batching versus other frameworks remains a feature demo.
- **Fan-out:** static has a lower aggregate median in both experiments, but the
  isolated pairs split two faster/two slower and p95 also changes direction.
  No consistent improvement is established on this machine.
- **Async:** static has a higher p50 in every pair in both experiments; isolated
  differences are 1.6–9.7%. The workload includes 100 awaited zero-delay timer
  hops, delivery and execution tracking, so this is wall time, not pure graph CPU.
  Static removes repeated subscription/zone capture but not the asynchronous
  workflow. The observed slowdown's cause has not been profiled; do not attribute
  it solely to graph tracking or extrapolate it to network-backed async state.
- **Chain:** static p50 is 9–23% higher in all isolated pairs; p95 aggregates are
  almost equal. Only the leaf is observed. Intermediate computeds remain pull-only,
  so this is not 1,000 independently active graph nodes. A plausible source-level
  explanation is that dynamic evaluation leaves an outer tracker installed,
  letting each inactive `value` read short-circuit the optional diagnostics check;
  static evaluation does not. That extra branch across a million nested reads
  could outweigh saved leaf tracking. This is a hypothesis, not a CPU-profiled
  attribution, and no runtime change was made to chase it here.

Keep dynamic tracking as the default. Use `staticDeps: true` only where the
application can promise that the dependency set never changes, then measure that
workload. Static mode is not a safe substitute for conditional dependency tracking
and these results do not justify changing all computeds to static mode.

## Validation and reproduction

- **119 benchmark tests pass**, including both modes for all six fixtures,
  consumer-delivery checks before verification, preserved dashboard defaults and
  explicit result labels. See [test log](tests.log).
- Final fatal-info analysis passes: [analysis log](analysis.log). Changed Dart
  files are formatted. The Python summary was checked against all stored suite
  samples and equivalent isolated grouping.
- **96/96 native cases pass; 4,800 total samples** across both experiments.
  Every result has 50 samples, successful verification and completed cleanup.
  Source inputs, mode labels, workload sizes, build/device identity and binary
  hashes were validated by the driver. This also exercises the optional native
  workload selector in all 48 isolated processes.
- All 80 runtime Dart library source hashes match the starting checkout:
  [unchanged-runtime manifest](runtime-unchanged.json). Runtime defaults and
  guarantees are unchanged. Full runtime CI/coverage was not rerun for this
  benchmark-only change; previous certification remains tied to its source.
- The normal interactive release app is restored with the final comparison's
  source stamp; see [build log](restore-interactive.log).

From the repository root, using two new output directories:

```sh
python3 scripts/compare_computed_modes.py --output /path/to/suite \
  --flutter /path/to/flutter
python3 scripts/compare_computed_modes.py --isolate-workloads \
  --output /path/to/isolated --flutter /path/to/flutter
```

Suite source digest: `cd70dcbabfb3a58e9413d166cc5cdab4c7ad40c9c77e6ed583f54912d0c6e90c`.
The initial selector-free harness sources are preserved under
[release/harness](release/harness/) and match that experiment's source manifest.
Final isolated source digest: `170a8f1a2c7c253449b23e83fc75ef6c7068f79252aea544a653ab2426fc22b0`.
Raw reports, source manifests, AOT hashes, pair schedules and summaries:
[initial suite](release/comparison.json), [suite summary](release/summary.json),
[isolated workloads](release-isolated/comparison.json),
[isolated summary](release-isolated/summary.json).

This is a current-runtime mode comparison. It does not rerun the `539f130`
reference comparison, settle the remaining general performance sign-off, or
recertify/publish the release candidate.
