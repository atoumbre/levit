# Benchmark App

This app compares Levit with several state-management stacks under a shared
benchmark harness.

## App methodology 2

The November 2026 app-harness corrections change the work being timed. Earlier
copied app reports (including the 2026-11-11 report) are **not comparable** with
new results. This is independent of the native `release_performance.dart`
candidate-versus-reference harness described below.

An iteration includes mutation, required computation, and consumer delivery.
`verify()` only inspects completed results after timing; it must not materialize
lazy values or drain pending delivery. Regression tests check captured consumer
values **before** verification, including every fan-out dependent and every
rapid-mutation notification. Each implementation lives for one benchmark session;
UI unmount and awaited resource cleanup finish before the next implementation.

- Fan-in changes one of the inputs and consumes the sum of every input.
- Fan-out consumes every computed output on every source change.
- The diamond and observed chain consume a result after **each** root update.
  Diamond intermediate notification counts can differ, so it stays approximate.
- Batch remains a feature demonstration, with different intermediate work. Its
  final aggregate is consumed inside timing. It is not a framework ranking.
- The DI demo measures warm root lookup plus increment, not scoped-widget
  lookup, registration, or disposal. Custom-map substitutes are named as such.
- Graph/async fixtures that use RxDart are labeled **RxDart**. The batch fixture
  using ValueNotifier is labeled **ValueNotifier (substitute)**, not BLoC.
- The list is virtualized, contains 1,000 items, and updates its first visible
  row. It measures whole-list notification/rebuild, not per-row state selection.
- The grid replaces 50 of 200 **keyed** items and checks that visible elements
  actually mount/unmount. Virtualization means the visible count varies with
  viewport size; it does not claim 50 visible mounts on every display.
- The nested-tree fixture rebuilds an observed leaf under 100 static containers.
  The progress-bar fixture measures individual updates, not sustained 60 fps.

The UI wall-time metric is **update to frame end**, including frame wait and
excluding raster completion. It must not be converted to FPS or described as
build time. The app separately records matched engine frame IDs and reports
build/raster p50 and p95. These cover the whole frame, not isolated framework CPU.
Missing/duplicate frame samples and timing timeouts reject the run. An unrelated
animated spinner was removed from the measurement surface.

Use **Copy Results** for Markdown, or **Copy JSON with raw samples** for raw wall
and frame samples. Both identify the methodology; Markdown labels the timing
boundary and prints matched frame statistics. The environment includes refresh
rate and a build-time source identity (explicitly `unrecorded` when omitted):

```sh
flutter run --release -d macos --dart-define=BENCHMARK_REVISION=YOUR_SOURCE_DIGEST
```

The dashboard, Markdown and console reports show a full assessment alongside
each **OK** or **Error** status. OK means execution, result verification and
cleanup succeeded. Error means the run failed those checks and its timings are
invalid for comparison; the error details remain available. These statuses
describe run validity, not a speed rating. JSON includes the same assessment
alongside the existing success flag and complete error details.

Record the source digest including local changes and retain `pubspec.lock` with
comparison evidence. Five warmups and one block of 50 samples are exploratory;
order rotates between workloads, not within repeated rounds of the same
workload. Repeat independent runs in reversed order on the same SDK/device for
performance conclusions. This app does not establish a real-application speedup
or a regression against another Levit revision by itself.

The native smoke entrypoint validates every framework/workload with production
work sizes and two measured iterations. It checks actual engine timing delivery;
its short run is a correctness check, not a performance comparison:

```sh
flutter build macos --release --target=lib/verify_app_benchmarks.dart
LEVIT_PERFORMANCE_RUN=1 build/macos/Build/Products/Release/benchmarks.app/Contents/MacOS/benchmarks > /tmp/levit-app-smoke.log 2>&1
```

The log contains an `APP_BENCHMARK_JSON:` record and a final PASS/FAIL marker.
Output uses the inherited log stream, preserving the macOS application sandbox.
The smoke binary exits after completion. Rebuild with `--target=lib/main.dart`
to return to the interactive dashboard.

## Repeating the dashboard comparison

`lib/compare_app_workloads.dart` mounts the real dashboard (including its sidebar)
and runs all 60 cases with the existing 50 samples and five warmups. It emits an
`APP_COMPARISON_JSON:` record, awaits unmount/cleanup and exits. The driver checks
identical benchmark sources/locks, stamps source digests, and rejects changed
window geometry or refresh rates:

```sh
python3 scripts/compare_app_performance.py --before-root /path/to/before \
  --after-root /path/to/after --output /path/to/evidence --flutter /path/to/flutter
```

Run the driver from the repository root on an otherwise idle machine. It builds
both revisions, then runs before → after → after → before in separate processes.
It retains build logs, raw samples, source manifests and AOT binary hashes.
`--mode=profile` is also supported. `--grid-only` isolates the unchanged grid
across all five frameworks; `--chain-only` isolates the unchanged Levit/vanilla
chain cases. These use normal dashboard selections, so report them separately
from the full suite: the surrounding workload history differs.
Restore the interactive app afterward with
`flutter build macos --release --target=lib/main.dart` from `benchmarks/`.

`lib/profile_app_workloads.dart` exposes `ext.levit.profile` for CPU/allocation
sampling of the same fan-in, fan-out, grid and chain implementations on that dashboard.
Its repeated eight-second loops are for identifying CPU costs, **not latency
comparisons**: logic iterations omit the normal inter-sample idle period.

## Comparing static and dynamic computed tracking

Run every computed dashboard workload in both modes from the repository root:

```sh
python3 scripts/compare_computed_modes.py --output /path/to/new-evidence \
  --flutter /path/to/flutter
```

The driver builds `lib/compare_computed_modes.dart` once in release mode and
starts eight separate processes: four per dependency mode. Four adjacent pairs
balance which mode runs first and whether workload order is forward or reversed.
`--mode=profile` is also supported. Run on an otherwise idle machine.

Add `--isolate-workloads` to run each workload in a fresh process (48 processes,
still four pairs and 200 measured samples per mode per workload). This removes
cross-workload history, including shared allocator/tracker state. Retain and
report this separately from the suite; it does not change the timed workload.

It reuses the diamond, fan-out, fan-in, async computed, batch and observed-chain
implementations, changing only `staticDeps`. Work sizes, subscriptions, five
warmups, 50 measured samples, correctness checks, 10ms inter-sample idle and
awaited cleanup are unchanged. All six dependency sets are fixed, so static mode
is valid. The chain and diamond observe their final output; intermediate
computeds retain their original subscription behavior. This is not a comparison
of independently subscribed nodes at every level.

Each JSON result labels its tracking mode. Evidence includes raw samples, source
and binary hashes, build/device metadata, workload sizes and per-process p50/p95.
`summary.json` aggregates independent process medians and records every paired
percentage difference; negative means static takes less time. It does not pool
consecutive samples as independent runs. This comparison isolates tracking mode,
not a change against an earlier revision or a ranking of other frameworks.

The normal dashboard still uses its original modes: diamond/async static,
fan-in/fan-out/batch/chain dynamic. Rapid mutation, DI and UI fixtures have no
computed mode to switch. Static tracking is an opt-in promise that dependencies
stay fixed; use dynamic tracking for conditional or changing dependency sets.
No runtime default is changed by this comparison.

The [2026-11-12 comparison](../reports/validation/0.1.0/2026-11-12-computed-modes/COMPARISON.md)
retains both suite and isolated results, with raw samples and variability limits.

The comparison binary exits after cleanup. Restore the interactive app from
`benchmarks/` with `flutter build macos --release --target=lib/main.dart`, adding
`--dart-define=BENCHMARK_REVISION=SOURCE_DIGEST` to identify the checkout.

## Comparing against the published release

`scripts/compare_published_performance.py` builds separate snapshots of the
current runtime and checksum-verified pub.dev archives. It runs the six computed
workloads in both modes, plus mutation, warm DI and four UI workloads. Each case
starts in a fresh process; four revision pairs alternate which revision runs
first. Both sides use the same SDK, non-Levit dependency lock and timed fixtures.

The driver takes an evidence directory containing `published-packages.json`
(the pub.dev API version, archive URL, checksum and pubspec for each runtime
package). The [2026-11-13 comparison](../reports/validation/0.1.0/2026-11-13-published-comparison/COMPARISON.md)
contains frozen metadata and archives for 0.0.11. Copy that metadata into a new
output directory to reproduce that exact baseline, then run from the repo root:

```sh
python3 scripts/compare_published_performance.py --prepare-only \
  --output /path/to/evidence --flutter /path/to/flutter
python3 scripts/compare_published_performance.py --measure-only \
  --output /path/to/evidence --flutter /path/to/flutter
```

Finish builds/tests before measurement. Preparation preserves the workspace and
normal interactive app, checks identical timed fixtures and non-Levit locks,
and records the compatibility edits: wrapping teardown with `Future<void>.sync`
for the old void-returning close API, and the published dashboard's old
`ref.autoDispose` spelling. These edits do not add the new runtime's cleanup
guarantees to the published version. Runtime library sources remain untouched.

The output retains raw samples, matched frame timings, per-pair changes, source
manifests, AOT hashes and validity failures. UI wall time includes frame waiting;
use the separate build/raster metrics for rendering-cost comparisons. These
workloads do not establish whole-application performance or lifecycle parity.

## Methodology

- The runner owns timing for every benchmark. Implementations no longer return
  their own durations.
- Every benchmark performs warmup iterations before measured samples.
- Every measured iteration must finish its framework-specific work before the
  sample is recorded.
- Every measured iteration is followed by a correctness check. A benchmark run
  fails if the expected state was not reached.
- Reports use per-iteration samples and publish median, mean, min/max, standard
  deviation, and sample count.
- Reports also include environment metadata: build mode, benchmark profile,
  iteration counts, OS/runtime details, CPU thread count, locale, selected
  frameworks/benchmarks, and display metrics when available.
- UI workloads use deterministic mutation schedules.
- UI list/grid benchmarks mutate the same plain backing collections across all
  frameworks and use the framework only for notification/rebuild.

## Benchmark Classes

- `Comparative`: Comparable stated workload and completion boundary; not an
  overall framework or application ranking.
- `Approximate`: Uses the closest available primitive when a framework does not
  expose the same abstraction directly.
- `Feature Demo`: Demonstrates a feature that is not a first-class primitive in
  every framework. Do not use these for headline rankings.

## Test Profile

The automated test suite uses a reduced benchmark profile so the harness can be
validated quickly in CI:

- `flutter test test/benchmark_runner_test.dart`

Production defaults remain in `lib/benchmark_config.dart`.

## Running The App

- `flutter run -d macos`

The in-app dashboard rotates framework order per benchmark to reduce simple
fixed-order bias.

## Reading Results

- Prefer median over mean for ranking.
- Check standard deviation before treating small deltas as meaningful.
- Treat `Approximate` and `Feature Demo` results as directional, not definitive.

## Native release comparison

`lib/release_performance.dart` is an automated macOS profile/release entrypoint.
It measures notifications, computed fan-out, scope creation/lookup/awaited cleanup,
task completion and a mounted 1,000-row list. It checks results and cleanup before
accepting samples. The JSON output includes all raw samples, actual build/raster
frame timings, diagnostic delivery counts, RSS and environment metadata. Timing
batches are matched by engine frame ID, so release-mode delivery delays cannot
mix warmup frames into the measurement or truncate the final batch.

```sh
flutter build macos --profile --target=lib/release_performance.dart
LEVIT_PERFORMANCE_RUN=1 LEVIT_DIAGNOSTICS=off build/macos/Build/Products/Profile/benchmarks.app/Contents/MacOS/benchmarks
flutter build macos --release --target=lib/release_performance.dart
LEVIT_PERFORMANCE_RUN=1 LEVIT_DIAGNOSTICS=off build/macos/Build/Products/Release/benchmarks.app/Contents/MacOS/benchmarks
```

Each process runs exactly one diagnostic state over three rounds. Set
`LEVIT_DIAGNOSTICS=off` or `LEVIT_DIAGNOSTICS=on`; the comparison runner sets it
for every process. Explicit monitor detachment is verified after every round. Logic workloads use
five warmups and 30 measured samples per round; UI uses ten warmup frames and 60
measured frames. Debug builds are rejected. Diagnostics serialize JSON into a
counting sink without retaining payloads or measuring network/disk IO. History is
10,000 events for comparison with the old monitor; the candidate queue is bounded
at 65,536 and any drop or incomplete delivery invalidates the run. Stack capture
is off; worker statistics follow the diagnostics setting. These are explicit
measurement settings, not recommended application defaults.

Run binaries sequentially on the same machine without concurrent test/build jobs.
Use the same workload source and Flutter SDK for each reference. Preserve and
identify any baseline adapter separately from the original runtime source.
`python3 benchmarks/tool/compare_release_performance.py REFERENCE_ROOT OUTPUT [BEFORE_ROOT]`
runs each revision in profile/release and each diagnostic state in a fresh
process, then repeats in reversed revision/diagnostic order (16 processes, or 24
with an optional before-optimization root). It validates sample counts and matching display
geometry, and preserves logs, JSON samples and six round medians per configuration.
The runner sets `LEVIT_PERFORMANCE_RUN=1` for both native hosts. This holds a
process-scoped macOS activity assertion during measurement to prevent background
idle throttling; it does not change system power settings. The assertion ends
when the window closes or the process exits, and the runner verifies its startup
marker before accepting results.
During these runs only, the benchmark window floats above ordinary windows so
macOS occlusion cannot suspend Flutter frame delivery. It is placed on the
available display with the highest scale factor; differing geometry invalidates
the run set. It does not take keyboard
focus and disappears on process exit. Frame waits fail after five seconds rather
than accepting interrupted rendering as a timing sample. Keep the display awake
and avoid interacting with the benchmark while it runs.
Compare round medians and sample variation; UI wall time includes frame pacing,
so use the separate build/raster timings when assessing rendering costs. RSS is
a process observation, not a retained-memory/leak measurement.

Both benchmark runners now fail when teardown fails and unmount UI before
releasing resources. Levit implementations await cleanup. End-of-frame waiting
measures build completion; it does not by itself prove raster completion.
The private benchmark macOS host targets macOS 12+ for the installed Xcode SDK.

The reference adapter must explicitly call `disable()` before awaiting `close()`:
the legacy monitor does not unregister hooks in `close()`. The teardown test must
pass against both versions. Never mix on/off measurements within one process.
Earlier mixed-state results are superseded and are unsuitable for speedup claims.

## Native CPU profiling

`lib/profile_runtime.dart` exposes `ext.levit.profile` in a native profile build.
The service extension accepts `workload` (`tasks`, `scopes`, `notify`, `fanout`)
and exercises verified work for five seconds. Set `LEVIT_DIAGNOSTICS=off|on` in
separate processes. Collect VM CPU samples and heap counters around each call;
profile instrumented runs independently from `release_performance.dart` timings.
The collector and captured profiles are retained with the performance-remediation
evidence. Heap counters are observations, not a complete allocation census.
The native comparison retains end-to-end samples, including the explicit
zero-duration event-loop wait used to drain delivery. Logic workloads also emit
`bodySamplesUs`, measured at the return from the awaited operation, and the
report includes the residual event-loop wait separately. This helps identify
scheduler variation in very short diagnostics-off workloads; it does not remove
delivery cost from the primary comparison. Reference and candidate use the same
instrumentation and continue to assert complete delivery before `flush`.
Logic workloads warm for at least five iterations and 500 ms before the 30
recorded samples; actual warmup counts and duration are retained. The list keeps
its ten matched-frame warmups. Both revisions use this sustained warmup to avoid
treating a millisecond-long cold burst as steady-state throughput. Body timings
include microtasks that run before the operation's future resumes, so use the
complete-delivery totals when comparing diagnostics pipelines.
