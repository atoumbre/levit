# Native performance comparison for Levit 0.1.0

Completed on 2026-11-11: eight native processes passed all correctness, cleanup,
diagnostic-delivery and frame-count checks. The comparison contains **8,640 timed
samples and 2,880 matched Flutter frames**. Failed/provisional probes remain
separate in `performance-probes/` and do not contribute to these results.

## Approved reference and method

The user approved committed revision
`539f130da148d1a802925d02363996f82ae4a323` on 2026-11-11 because the original
unpublished 0.0.12 archive is unavailable. This reference excludes those
unpublished changes. Differences therefore span both the unpublished work and
the 0.1.0 implementation; they cannot all be attributed to one milestone.

All 74 reference runtime source/manifests were verified byte-for-byte against
Git (`performance-reference-integrity.log`). Only the benchmark workload,
monitor adapter, benchmark dependency configuration and macOS measurement host
are overlaid. Both sides use the same workload and Flutter SDK, and all
44 external dependency versions match (`performance-external-versions.json`).
The reference adapter is preserved in `performance-reference-adapter.dart.txt`;
`performance-reference-setup.json` records all verified paths, common source
hashes and exact dependency/adapter text needed to recreate the overlay.

Measurements use real native macOS profile and release executables on an
Apple M1 Pro, 8 CPU cores, 16 GiB RAM, macOS 26.6.2 (25G83), Dart 3.12.2 and
Flutter 3.44.8. No thermal/performance warning was reported before measurement.
The application records display geometry, runtime details, timestamps and RSS.
No builds or test suites run concurrently with the final measurements. Both
hosts hold the same process-scoped macOS activity assertion, verified by a native
startup marker and recorded in JSON. It ends with the process and does not alter
system power settings. The measurement-only window floats above ordinary windows
without taking keyboard focus, preventing occlusion from suspending frame delivery.
Every frame wait has a five-second timeout. No UI automation or interaction runs
during final collection. Earlier unguarded/interrupted probes are retained
separately for comparison; only guarded measurements contribute to the final tables.

Each process alternates diagnostics off/on over three rounds. A second pass
reverses reference/candidate process order. Each logic configuration therefore
has six round medians from 180 measured samples, after five warmups per round.
UI configurations have 360 measured frames after ten warmups per round. Engine
frame IDs match timing batches to exactly the measured frames, excluding warmups
and waiting for delayed release-mode reports. Geometry must match across runs.

Workloads: 10,000 observed writes; 128 computed consumers reading every one of
100 updates; 100 scope creation/lookup/cleanup cycles; 100 leaf tasks through a
four-slot engine; and updates of a mounted, virtualized 1,000-row list
(visible/cached rows render). Every sample checks its results and real completion. Diagnostic drops or incomplete delivery invalidate
the run. The task workload has no optional application task-monitor bridge.

Diagnostics serialize events to JSON and UTF-8 in a counting sink, without
external network/disk IO or retained sink payloads. Both use 10,000-event monitor
history to match the old monitor's fixed capacity. The candidate queue is bounded
at 65,536; the old queue is unbounded. Worker statistics follow the diagnostics
setting and stack capture is disabled. These are comparison settings, not the
candidate's defaults (history/statistics are disabled by default).

The candidate additionally freezes/redacts envelopes and emits ownership progress;
the old monitor does not provide the same contracts. Diagnostic cost comparisons
include those behavior changes. RSS is a process observation after each workload,
not proof of retained memory or leaks. UI wall time includes vsync pacing; build
and raster timings are reported separately.

## Results

Latency is the median of six round medians; negative change means less elapsed
time. All raw samples and round medians remain in `performance-*-{1,2}.json` and
`performance-summary.json`. Display geometry was 1,600 × 1,200 physical pixels at
2× pixel ratio in every process.

With diagnostics off, release notification latency improves 88.9% and computed
fan-out improves 46.9%. Scope lifetime cost rises 18.4% (about **0.55 µs per scope**).
Leaf scheduling rises from **1.62 to 4.83 µs per task**, approximately three times
the old cost. These workloads now include awaited ownership and structured task
bookkeeping; the comparison does not isolate the cost of each implementation
change from the unavailable unpublished work.

With diagnostics on, notification/fan-out latency is approximately 2.7–2.8 times
the reference and scope lifetime latency is 5.8 times the reference. These are
material measured regressions. The candidate provides frozen/redacted envelopes,
bounded transport accounting and more ownership lifecycle events. For example,
the scope block delivers 42,000 events versus 28,128 in the reference (counts
include warmups and any preceding cleanup delivery). That event-volume difference
explains part, not all, of the extra work. The task workload emits no monitor
events because the optional task bridge is not installed. Monitoring history and
worker statistics remain opt-in; keep the comparison configuration out of normal
production hot paths unless that diagnostic detail is needed.

UI wall medians stay near the display's 8.33 ms pacing. Release engine build
medians are 1.68 ms off / 1.65 ms on for the candidate, versus 1.57 / 1.60 ms for
the reference. Round variation overlaps; these small UI differences do not
establish a consistent rendering speedup or regression. Candidate build p95 stays
at or below 2.53 ms and raster p95 at or below 0.60 ms in these runs.

The comparison gate is complete with the above costs explicitly recorded. No
zero-regression performance budget was specified; this certification preserves
the new ownership/diagnostics behavior and makes the measured tradeoffs reviewable.

### Profile workload latency

| Diagnostics | Workload | Reference ms | Candidate ms | Change |
| --- | --- | ---: | ---: | ---: |
| Off | 10,000 observed writes | 2.294 | 0.176 | -92.3% |
| Off | 128 computed consumers × 100 writes | 6.647 | 3.751 | -43.6% |
| Off | 100 scope lifetimes | 0.310 | 0.357 | +15.2% |
| Off | 100 leaf tasks | 0.164 | 0.499 | +204.0% |
| Off | Virtualized 1,000-row list: frame wall time | 8.310 | 8.325 | +0.2% |
| On | 10,000 observed writes | 46.088 | 133.476 | +189.6% |
| On | 128 computed consumers × 100 writes | 62.527 | 177.528 | +183.9% |
| On | 100 scope lifetimes | 4.010 | 23.837 | +494.5% |
| On | 100 leaf tasks | 0.164 | 0.555 | +239.1% |
| On | Virtualized 1,000-row list: frame wall time | 8.305 | 8.320 | +0.2% |

### Release workload latency

| Diagnostics | Workload | Reference ms | Candidate ms | Change |
| --- | --- | ---: | ---: | ---: |
| Off | 10,000 observed writes | 2.333 | 0.259 | -88.9% |
| Off | 128 computed consumers × 100 writes | 6.170 | 3.278 | -46.9% |
| Off | 100 scope lifetimes | 0.297 | 0.352 | +18.4% |
| Off | 100 leaf tasks | 0.162 | 0.483 | +198.9% |
| Off | Virtualized 1,000-row list: frame wall time | 8.320 | 8.324 | +0.0% |
| On | 10,000 observed writes | 46.692 | 130.967 | +180.5% |
| On | 128 computed consumers × 100 writes | 62.428 | 171.599 | +174.9% |
| On | 100 scope lifetimes | 4.180 | 24.146 | +477.7% |
| On | 100 leaf tasks | 0.159 | 0.493 | +209.4% |
| On | Virtualized 1,000-row list: frame wall time | 8.287 | 8.295 | +0.1% |

### Flutter engine timings

Pooled medians / nearest-rank p95, milliseconds; 360 matched frames per row.

| Mode | Diagnostics | Revision | Build median / p95 | Raster median / p95 |
| --- | --- | --- | ---: | ---: |
| profile | Off | reference | 1.708 / 2.468 | 0.442 / 0.617 |
| profile | Off | candidate | 1.565 / 2.386 | 0.406 / 0.564 |
| profile | On | reference | 1.666 / 2.345 | 0.429 / 0.617 |
| profile | On | candidate | 1.559 / 2.166 | 0.405 / 0.530 |
| release | Off | reference | 1.569 / 2.252 | 0.413 / 0.594 |
| release | Off | candidate | 1.677 / 2.526 | 0.413 / 0.592 |
| release | On | reference | 1.601 / 2.289 | 0.398 / 0.566 |
| release | On | candidate | 1.651 / 2.334 | 0.410 / 0.550 |


## Harness corrections made during certification

- Await Levit teardown, unmount after failures, and fail the result if cleanup
  fails. Enable ownership auto-linking in the regular benchmark application.
- Check that every computed consumer actually reads every fan-out update, so
  lazy invalidation cannot silently reduce the measured work.
- Match timing records by Flutter engine frame ID. A fixed delay missed release
  batches; raw animation timestamps are not suitable as frame identities on
  this platform. Failed probes are retained and excluded from the comparison.
- Hold a process-scoped macOS activity assertion, keep the measurement window
  visible without taking focus, and bound every frame wait. Earlier probes showed
  late-round build medians of 6–8 ms and a visibility-related frame stall. The
  controlled candidate repeats have round build medians of 1.46–2.05 ms, with no
  stalls. These combined host controls removed that observed distortion; the
  probes do not isolate which OS mechanism caused each delay.
- Update the private macOS benchmark host to macOS 12+, the minimum supported
  by the installed Xcode SDK. Runtime package platform support is unchanged.

Six focused regressions cover cleanup failure and delayed/out-of-order frame
timing delivery. The complete benchmark harness has 66 passing tests. Those
debug tests validate the harness; their timings are not the performance evidence.

## Reproduction and limits

Build `benchmarks/lib/release_performance.dart` in profile and release in both
roots, following `benchmarks/README.md`, then run:

```sh
python3 benchmarks/tool/compare_release_performance.py REFERENCE_ROOT OUTPUT
```

The script retains raw logs/JSON, executable hashes, all samples and round medians.
Compare round variation before interpreting small differences. These are native
macOS measurements on one machine, not mobile/web throughput guarantees.
Normal desktop background applications were not disabled. Candidate RSS observations
range from 102.2 to 159.4 MiB; no retained-memory/leak conclusion follows from that
range. The JSON counting transport does not measure WebSocket/network/disk latency.
Browser support is validated by separate compilation contracts. The reference
change is explicit; no comparison against the missing archive is claimed.
