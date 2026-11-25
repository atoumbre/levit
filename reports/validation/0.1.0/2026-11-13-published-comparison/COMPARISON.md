# Current Levit versus latest published release — 2026-11-13

Generated run artifacts were removed during cleanup on 2026-11-24. Historical artifact paths refer to Git commit `bd1a095`.


The current 0.1.0 checkout improves dynamic diamond, fan-in, fan-out and both chain
modes against published 0.0.11 in every matched pair. Performance is not uniformly
better: static async and progress-bar rendering are slower in every pair, with
substantial variation in the size of the slowdown. Other static paths and warm
DI have mixed signals. Overall performance sign-off remains open.

## Published baseline and current snapshot

The live [pub.dev registry](https://pub.dev/api/packages/levit_flutter) reports
**0.0.11**, published **2026-08-06**, as the latest release for all eight runtime
packages checked: levit, levit_flutter, levit_dart, levit_dart_core,
levit_flutter_core, levit_reactive, levit_scope and levit_monitor.
The current checkout targets **0.1.0** and remains unpublished.

Registry metadata and archive SHA-256s (`published-packages.json`) are retained.
Every downloaded archive was verified against its registry checksum. Published
runtime code was extracted unchanged into an isolated snapshot. All 58 runtime
Dart library files, plus two packaged example library files, are byte-identical
to `539f130`; no library files exist only in one side of that source comparison.
See the file comparison (`published-versus-539f130.json`). This confirms that the
previous approved Git reference represents the published runtime; it does not
make old measurements interchangeable with this new experiment.

The current source was copied from the working tree, including uncommitted work.
Both measured source snapshots are retained in source archives (`source-archives.json`).
Their source manifests/digests and AOT hashes are recorded in
prepared inputs (`prepared.json`):

- Published: `90346e01aa5b8785eda05b6621c0fcad82c28539b18c4dd986b54ef1fb0fe99a`.
- Current: `1061bffa235aafc6041661564fd9ed90c661d0386d8ac12658fb2ae52f5b45d8`.

The comparison changed no runtime library, workspace dependency or normal
interactive app binary. Nothing was published or recertified.

## Measurement boundary

- Native macOS **release** builds, Flutter 3.44.8 / Dart 3.12.2, macOS 26.6.2,
  eight logical processors, fixed 800×600 logical viewport at 2× and 120 Hz.
- **18 cases:** six computed workloads in both dynamic/static modes, plus
  mutation, warm root DI and four UI workloads. Each case has four runs per
  revision, each in a fresh process. Pair order is published→current,
  current→published, current→published, published→current.
- Identical timed implementations, configurations, observer wiring and runner
  for both versions. Five warmups and 50 measured samples per process; the
  existing logic/UI pacing and consumer-delivery requirements are preserved.
  All non-Levit lockfile entries match. Diagnostics remain unattached.
- Compatibility edits only: both snapshots wrap resource teardown using
  `Future<void>.sync(close)` to accept either void or asynchronous returns. The
  published dashboard uses `ref.autoDispose` where current uses `ref.own`.
  These edits are outside timed work. Exact patches:
  published (`published-compatibility.patch`), current (`current-compatibility.patch`).
  Wrapping a void-returning API does not retrofit 0.1.0 cleanup guarantees into
  0.0.11. These are steady-state timings, not a lifecycle-parity benchmark.
- Setup, verification and cleanup are outside timing. Logic timing includes
  required computation and consumer delivery. UI wall time includes frame
  waiting and excludes raster completion. Build/raster measurements are matched
  engine frames for the whole mounted app; they are not isolated Levit CPU time.
- Tables use the median of four per-process p50s or p95s. Each process p95 uses
  nearest rank over 50 samples. Change is `(current / published − 1) × 100`;
  negative means less time. All four paired percentage changes are shown because
  a ratio of aggregate medians can differ considerably from individual pairs.
  No statistical significance or confidence interval is claimed.
- Browser and system maintenance processes were active before measurement; this
  was not an otherwise-idle dedicated machine. Builds and tests finished before
  sampling. Background activity, scheduling and power-state variation limit
  precision, especially for small operations, async wall time and frame tails.

## Logic: p50

Units are microseconds per complete benchmark iteration: diamond 10,000 root
writes; fan-out 1,000 delivered outputs; fan-in a sum over 1,000 inputs after one
update; async 100 sequential awaited updates; batch 1,000 writes over 100 sources;
chain 1,000 writes through 1,000 levels; mutation 1,000,000 delivered updates;
DI 1,000 warm lookups and increments.

| Workload | Mode | Published 0.0.11 (µs) | Current 0.1.0 (µs) | Time change | Four paired changes |
|---|---|---:|---:|---:|---|
| Diamond | dynamic | 3,550.25 | 1,447.25 | -59.2% | -56.0%, -69.8%, -52.0%, -48.2% |
| Diamond | static | 1,392.50 | 1,201.75 | -13.7% | -20.6%, -21.1%, -6.6%, -12.8% |
| Fan-out | dynamic | 537.75 | 412.00 | -23.4% | -8.1%, -59.6%, -17.0%, -56.8% |
| Fan-out | static | 660.25 | 761.75 | +15.4% | -0.2%, +6.6%, +48.6%, +126.3% |
| Fan-in | dynamic | 319.00 | 136.50 | -57.2% | -74.8%, -19.1%, -62.9%, -50.6% |
| Fan-in | static | 47.00 | 63.00 | +34.0% | -27.6%, -20.0%, +73.5%, +196.3% |
| Async computed | dynamic | 2,684.00 | 2,791.75 | +4.0% | -18.2%, -7.6%, +83.4%, -33.6% |
| Async computed | static | 2,228.00 | 4,864.00 | +118.3% | +11.2%, +58.1%, +174.3%, +87.5% |
| Batch | dynamic | 137.25 | 123.00 | -10.4% | -14.6%, -24.0%, -5.7%, +12.8% |
| Batch | static | 42.75 | 47.00 | +9.9% | +167.1%, -15.3%, +7.0%, -2.0% |
| Deep chain | dynamic | 27,047.75 | 23,796.25 | -12.0% | -13.2%, -6.7%, -12.2%, -16.3% |
| Deep chain | static | 31,199.25 | 26,771.00 | -14.2% | -14.4%, -10.8%, -16.2%, -14.4% |
| Mutation | default | 14,233.50 | 14,357.50 | +0.9% | +0.8%, +0.3%, +0.8%, +1.6% |
| Warm DI | default | 40.25 | 49.25 | +22.4% | +32.0%, +2.6%, +62.5%, -10.8% |

## Logic: p95

| Workload | Mode | Published 0.0.11 (µs) | Current 0.1.0 (µs) | Time change | Four paired changes |
|---|---|---:|---:|---:|---|
| Diamond | dynamic | 4,833.00 | 2,345.00 | -51.5% | -53.9%, -72.5%, -36.2%, -25.1% |
| Diamond | static | 1,787.50 | 1,876.50 | +5.0% | +53.7%, -8.8%, +6.7%, -1.5% |
| Fan-out | dynamic | 1,492.00 | 714.50 | -52.1% | -38.7%, -61.0%, -45.9%, -61.7% |
| Fan-out | static | 2,003.00 | 1,417.50 | -29.2% | -32.0%, -33.2%, +5.2%, +22.0% |
| Fan-in | dynamic | 749.00 | 489.50 | -34.6% | -44.0%, -22.6%, -64.6%, -13.4% |
| Fan-in | static | 129.50 | 147.50 | +13.9% | -48.5%, +95.7%, +28.9%, -2.4% |
| Async computed | dynamic | 5,519.00 | 3,897.50 | -29.4% | -18.0%, -46.6%, +82.0%, -46.1% |
| Async computed | static | 5,260.00 | 6,721.00 | +27.8% | -9.4%, -24.8%, +161.0%, +38.2% |
| Batch | dynamic | 336.00 | 229.50 | -31.7% | +11.5%, -34.6%, -22.1%, -42.7% |
| Batch | static | 56.00 | 103.50 | +84.8% | +264.7%, +149.2%, +13.2%, -20.5% |
| Deep chain | dynamic | 28,209.00 | 28,072.50 | -0.5% | -2.0%, +4.2%, +0.9%, +2.1% |
| Deep chain | static | 32,310.50 | 27,690.50 | -14.3% | -14.6%, -10.4%, -17.4%, -13.4% |
| Mutation | default | 14,595.00 | 14,627.50 | +0.2% | -1.0%, -1.0%, +0.9%, +1.5% |
| Warm DI | default | 56.50 | 109.50 | +93.8% | +22.2%, +29.8%, +236.2%, -34.8% |

## UI: build p50

| Workload | Mode | Published 0.0.11 (µs) | Current 0.1.0 (µs) | Time change | Four paired changes |
|---|---|---:|---:|---:|---|
| Virtualized list | default | 640.50 | 621.25 | -3.0% | +2.8%, -3.4%, -2.6%, -52.7% |
| Nested leaf | default | 1,023.25 | 1,112.50 | +8.7% | +101.7%, +15.0%, -7.7%, -4.3% |
| Grid churn | default | 2,930.00 | 2,982.00 | +1.8% | -11.4%, -1.4%, +3.9%, +0.3% |
| Progress bar | default | 438.25 | 700.00 | +59.7% | +138.1%, +13.5%, +26.6%, +3.3% |

## UI: build p95

| Workload | Mode | Published 0.0.11 (µs) | Current 0.1.0 (µs) | Time change | Four paired changes |
|---|---|---:|---:|---:|---|
| Virtualized list | default | 1,184.50 | 965.00 | -18.5% | -2.6%, -20.0%, -18.0%, -37.5% |
| Nested leaf | default | 1,512.50 | 1,587.00 | +4.9% | +0.1%, +11.9%, +7.0%, -1.2% |
| Grid churn | default | 4,575.50 | 4,715.00 | +3.0% | +0.6%, +10.9%, +17.8%, -4.0% |
| Progress bar | default | 845.00 | 1,067.50 | +26.3% | +211.6%, +38.0%, +2.7%, +9.2% |

## UI: raster p50

| Workload | Mode | Published 0.0.11 (µs) | Current 0.1.0 (µs) | Time change | Four paired changes |
|---|---|---:|---:|---:|---|
| Virtualized list | default | 572.75 | 568.25 | -0.8% | -0.7%, -2.0%, +0.4%, -49.0% |
| Nested leaf | default | 1,160.50 | 1,245.00 | +7.3% | +96.5%, +15.9%, -4.1%, -2.6% |
| Grid churn | default | 959.00 | 970.25 | +1.2% | -3.2%, +2.2%, +4.8%, -2.0% |
| Progress bar | default | 772.50 | 1,189.75 | +54.0% | +134.4%, +3.8%, +25.1%, +7.3% |

## UI: raster p95

| Workload | Mode | Published 0.0.11 (µs) | Current 0.1.0 (µs) | Time change | Four paired changes |
|---|---|---:|---:|---:|---|
| Virtualized list | default | 1,057.00 | 727.50 | -31.2% | +8.3%, +0.3%, -50.9%, -11.7% |
| Nested leaf | default | 1,732.00 | 1,930.00 | +11.4% | +15.6%, -1.1%, +63.5%, +9.8% |
| Grid churn | default | 1,212.00 | 1,110.50 | -8.4% | -3.5%, -3.3%, +5.1%, -18.0% |
| Progress bar | default | 1,450.50 | 1,804.00 | +24.4% | +224.0%, +33.1%, +9.3%, -28.6% |

## UI: update-to-frame-end wall time

The four medians remain near 6.8–6.9ms. This largely reflects frame scheduling;
flat wall time does not prove that rendering costs are unchanged, and it must not
be converted to FPS. The separate frame statistics above show the differences.

| Workload | Mode | Published 0.0.11 (µs) | Current 0.1.0 (µs) | Time change | Four paired changes |
|---|---|---:|---:|---:|---|
| Virtualized list | default | 6,953.50 | 6,889.00 | -0.9% | -0.3%, +0.4%, -2.0%, -2.4% |
| Nested leaf | default | 6,905.25 | 6,914.75 | +0.1% | +0.9%, -0.2%, -0.6%, +0.6% |
| Grid churn | default | 6,854.50 | 6,774.50 | -1.2% | -0.2%, +0.3%, -0.9%, -2.6% |
| Progress bar | default | 6,868.75 | 6,800.50 | -1.0% | -1.8%, +0.9%, +0.1%, -4.7% |

## UI: update-to-frame-end p95

| Workload | Mode | Published 0.0.11 (µs) | Current 0.1.0 (µs) | Time change | Four paired changes |
|---|---|---:|---:|---:|---|
| Virtualized list | default | 7,664.00 | 7,438.50 | -2.9% | +0.5%, -2.9%, -3.5%, -13.1% |
| Nested leaf | default | 8,000.00 | 7,894.00 | -1.3% | +5.8%, -2.8%, -1.9%, -2.3% |
| Grid churn | default | 8,623.50 | 8,591.00 | -0.4% | +11.8%, +2.2%, -4.7%, -9.2% |
| Progress bar | default | 7,875.50 | 7,837.00 | -0.5% | +4.6%, +7.4%, -15.8%, -0.5% |

## What the measurements support

1. **Dynamic computed improvements are present against the actual published
   runtime.** Diamond is 48–70% lower per pair, fan-in 19–75% lower and fan-out
   8–60% lower. Each also has lower p95 in every pair. These are the ordinary
   dynamic paths, not benchmarks switched to static mode.
2. **Deep-chain medians improve in both modes.** Dynamic p50 is 7–16% lower and
   static p50 11–16% lower per pair. Dynamic p95 is mixed and roughly flat in
   aggregate; static p95 improves in every pair. As before, only the leaf is
   observed: intermediate computeds are pull-only, not independently active nodes.
3. **Static async is a remaining concern.** All four p50 pairs are slower,
   ranging from +11% to +174%. The ratio of aggregate medians is +118%, while
   p95 is mixed. This includes zero-delay timer hops, computation, delivery and
   execution bookkeeping. The cause has not been profiled in this experiment;
   the magnitude is too variable to treat as a fixed release overhead.
4. **Progress-bar rendering is another concern.** Build p50 is higher in every
   pair (+3% to +138%) and build p95 is higher in every pair. Aggregate build p50
   rises from 0.438ms to 0.700ms; raster p50 is also higher in every pair.
   Flat frame-wait wall time does not erase that result. It still needs CPU/frame
   attribution and a quieter confirmation before assigning a runtime cause.
5. **Static fan-in/fan-out/batch and warm DI are not settled.** Their aggregate
   medians are higher, but paired changes reverse direction. Dynamic async and
   batching also have mixed pairs. Retain them as investigation signals, not
   established release-wide regressions or wins.
6. **Mutation is effectively close to parity in this experiment.** Its median
   is +0.9% in aggregate (+0.3% to +1.6% across pairs), with near-flat/mixed p95.
   Grid/list/nested-leaf build and raster results are mixed; this run does not
   establish a general UI speedup.

No meaningful application-wide percentage can be obtained by averaging these
unrelated workloads. Their operation counts and application frequencies differ.
These measurements assess the specified completed-work paths; they do not measure
memory, startup, worker cancellation, task groups, query refresh or inspector cost.

## What 0.1.0 adds beyond timings

Published 0.0.11 already includes ownership APIs, scopes/stores, keyed families,
async concurrency options, tasks and monitoring. The current release strengthens
those contracts and adds workflows/tooling; it is not the first version with
those foundations. The cumulative [migration guide](../../../../docs/MIGRATION_0.1.0.md)
describes the breaking changes.

| Area | Published 0.0.11 | Current 0.1.0 checkout |
|---|---|---|
| Lifetimes | Reactive close APIs return void; basic resource ownership | Awaitable cancellation/draining, cleanup-error aggregation and tracked pending work |
| Flutter scopes | Existing scope widgets and async initialization | Serialized replacement, generation isolation, cleanup failure/retry and awaitable lifecycle controller |
| Stores/observation | Existing store recipes and mutable reactive interfaces | Definition-based store identity, typed overrides/lookups, observation-only `LxReadable` and isolated testing APIs |
| Families/queries | Raw keyed family resources | Stable refreshable handles, bounded inactive retention and task-backed query families |
| Tasks | Existing tasks/conflict policies | Structured groups, cancellation trees, inherited deadlines, bounded scheduling and typed outcomes |
| Tooling | Monitor primitives/transports | Awaitable bounded/redacted monitoring, local inspector CLI/UI and publishable lifecycle lints |
| Flutter adapters | Existing reactive widgets/helpers | Borrowing ValueListenable integration and corrected elapsed-time countdown |
| SDK | Dart 3.0+/Flutter 3.0+ declared by the published kit | Dart 3.12+/Flutter 3.44+ |

Persistence remains in the independent ecosystem roadmap. The current checkout
removes obsolete APIs directly and requires migration; it has not been published.
The new guarantees are useful, but this comparison alone does not establish that
all measured overhead is necessary or explained by them.

## Validation, reproduction and release status

**144/144 cases passed:** 7,200 wall-time samples and 1,600 matched engine frames.
Both snapshots passed all 51 selected computed-mode/delivery contract tests
(102 total): published tests (`published-computed-tests.log`),
current tests (`current-computed-tests.log`). Current benchmark fatal-info analysis
and formatting pass: analysis (`analysis.log`), validation summary (`validation.json`).
All source/binary identities remained unchanged through measurement. Resolved
Levit package paths were verified to point into the corresponding snapshot.

Raw per-process reports/logs are under runs (`runs/`); summary.json (`summary.json`)
contains every per-process p50/p95 and paired change. Build logs, lockfiles,
compatibility patches and published archive checksums are retained here.
Prepared source archives preserve the inputs independently of temporary builds.

To reproduce this baseline, copy `published-packages.json` into a new evidence
directory, then run from the repository root:

```sh
python3 scripts/compare_published_performance.py --prepare-only \
  --output /path/to/evidence --flutter /path/to/flutter
python3 scripts/compare_published_performance.py --measure-only \
  --output /path/to/evidence --flutter /path/to/flutter
```

Preparation creates separate temporary trees; it does not replace workspace
packages or its interactive app. Run measurement on an idle machine after builds
and tests finish. Re-query the pub.dev API to choose a newer published baseline.

This comparison is complete. **Overall performance sign-off remains open** for
unattributed signals, particularly static async and progress rendering, alongside
previously tracked DI/static-path variability. This is not candidate
recertification, and nothing has been published.
