# Levit 0.1.0 performance remediation

Generated run artifacts were removed during cleanup on 2026-11-24. Historical artifact paths refer to Git commit `bd1a095`.


**Performance sign-off complete for this measured matrix; not published.** The final evidence combines complete matrices **9 and 10**, using the same
executables and AOT frameworks: **32 isolated native processes, 17,280 timed
samples and 5,760 matched Flutter frames**. Every result, delivery, teardown and display check passes. Source and
functional certification are tracked separately in [CANDIDATE.md](CANDIDATE.md).

The large task, monitor and scope regressions have been addressed while retaining the new lifecycle and diagnostic guarantees. Across both complete exact-binary matrices, release tasks are 3.1% faster and monitored state workloads are 2.4–5.2% faster. Release scope lifetimes retain a **+1.3%** difference: **2.320 versus 2.290 µs per lifetime**. Small slower results and variable UI engine timings remain explicit; this sign-off is not a claim of universal performance parity.

There is no meaningful single “overall performance” percentage across these
workloads: their units and application frequencies differ. The tables retain
all measured costs, including slower results.

## Approved baseline and corrected measurement

The user approved **539f130da148d1a802925d02363996f82ae4a323** because the original
unpublished 0.0.12 archive is missing. Those unpublished changes are excluded;
this is an explicit baseline substitution.

The legacy monitor's `close()` did not unregister middleware. The previously
reported mixed-diagnostics speedups are withdrawn. Both benchmark adapters now
explicitly disable before awaiting close and assert removal from both registries.
Diagnostics off/on run in separate processes. The baseline's asynchronous
resource disposal is awaited; it is not treated as synchronous cleanup.

Historical reports and certificates are preserved in
[performance-signoff-reopened](performance-signoff-reopened/PERFORMANCE.md) and
`superseded-mixed-diagnostics/`. The earlier 24-process corrected matrix remains
historical evidence; its source and warmup method differ from this matrix.
Intermediate remediation matrices 1–8 are retained. **Comparison 6 is excluded**:
test compilation overlapped measurement. Passing correctness assertions there
cannot make its timings admissible. All later cited matrices run without
concurrent builds, tests, profilers or evidence compression.

## Controls and interpretation

- Reference runtime: 74 package source/manifests match Git. The common harness,
  native host and adapter changes are recorded in
  reference integrity (`performance-remediation/reference-integrity.json`).
- Candidate runtime: exact hashes (`performance-remediation/replicated-comparison/runtime-source.json`)
  and patch from the previous candidate (`performance-remediation/replicated-comparison/runtime-from-9ea48ef.patch`).
  Every raw run records executable and AOT framework SHA-256 values.
  Replication verification (`performance-remediation/repeat-status.json`) proves
  that the second matrix used the same binaries, with no source changes. Both
  revisions use the same 41 hosted dependency versions (`performance-remediation/external-versions.json`).
- Host: Apple M1 Pro, eight cores, 16 GiB RAM, macOS 26.6.2; Dart 3.12.2 /
  Flutter 3.44.8. All windows use the same 1600 × 1200 physical pixels, 2× scale,
  display 1 and 120 Hz. Visible unfocused windows use identical process activity
  guards. System power settings are unchanged; ordinary desktop background apps
  remain running.
- Each process runs three rounds in one diagnostics state. A second pass reverses
  revision and diagnostics order. Each logic workload warms for **at least five
  iterations and 500 ms**, then records 30 samples. UI uses ten warmup frames and
  60 measured frames. Each configuration therefore has six round medians, 180
  logic samples or 360 matched frames **per matrix**. The combined report uses all
  12 round medians, 360 logic samples or 720 matched frames per configuration. Reported latency is the median of round
  medians; negative change means faster.
- The sustained warmup replaces an unstable five-short-burst warmup identically
  on both revisions. Large earlier off-mode notification fluctuations were also
  visible in operation-return checkpoints, not just event-loop waiting. Warmup
  iteration counts and elapsed time are retained in every raw row. These are
  **warm steady-state** results, not cold-start measurements.
- Logic timing includes complete notification/stream delivery and an event-loop
  turn. Flush after timing verifies that delivery did not escape measurement;
  dropped events or incomplete cleanup reject a run. `bodySamplesUs` is an
  auxiliary checkpoint after awaiting the operation. It can include monitor
  microtasks and must not be presented as synchronous producer latency or used to
  compare differently batched transport pipelines. Complete-delivery latency is
  the primary result.
- Monitoring serializes JSON/UTF-8 into a counting sink without retaining sink
  payloads or network/disk IO. History capacity is 10,000; candidate queue capacity
  is 65,536 and legacy buffering is unbounded. Stack capture is off; worker
  statistics follow diagnostics mode. History/statistics remain off by default
  in normal applications. The optional task-monitor bridge is absent, so the
  leaf-task workload emits no monitor events.
- Scope fixtures create, resolve and await disposal of 100 resources with an
  asynchronous `onClose`. The final scope CPU profiles use this same async
  fixture. Earlier exploratory scope profiles used a synchronous disposer and
  are labelled historical; their throughput is not timing evidence.

## Profile findings and fixes

| Area | Observed avoidable work | Change and preserved guarantees |
| --- | --- | --- |
| Monitor capture | Timestamp reparsing consumed 16–21% of monitored CPU samples in the previous candidate; repeated map copies/freezing added allocation work. | Reuse the captured timestamp, freeze private field assignments once, and use an immutable shared layout for scalar state events. Preserve redaction before retention, custom JSON serialization, cycle rejection and immutable nested data. |
| Ownership diagnostics | Repeated full-map expansion and unchanged progress descriptions multiplied event/serialization work. | Versioned compact records remain self-contained. Decode named metadata lazily; suppress identical progress and use actual `scope_dispose` for terminal completion. Preserve pending initialization/cleanup, replay after drops, reconnect snapshots and inspector/relay rendering. |
| Leaf tasks | Eager outcome futures, unused cancellation signals, no-cache continuation layers, runner proxies and per-ID timestamps. | Allocate observations on demand, retain one task execution context, track actual runner futures and generate opaque monotonic IDs. Preserve asynchronous admission, valid null results, late failures, cancellation reasons, group identity and draining through finally blocks. |
| Scope lifetimes | Unused bookkeeping and futures, repeated collection construction and progress dispatch. Required initialization guards remain visible in CPU profiles. | Allocate optional work/maps lazily; avoid unnecessary cleanup continuations and temporary singleton cancellation lists. Keep stable disposal futures, LIFO release, inherited initialization guards, cancellation/draining and aggregate failure reporting. |
| Closing-scope guard | Registrations removed from lookup were omitted from self-disposal checks while their task still drained. | Check retiring registrations too. The permanent test fails before the fix and passes after it. |
| Middleware failure paths | A throwing deletion callback could skip later cleanup; a final observer failure could mask earlier errors. | Attempt all deletion/disposal observers and all resource cleanup. Aggregate errors after async release. Cover dispose, delete, reset and non-owning aliases. |

CPU summary (`performance-remediation/profile-summary.json`) and
matching async-scope profiles (`performance-remediation/final-async-profile-summary.json`)
retain sampled function counts. Original VM-service responses are losslessly
compressed; their manifest (`performance-remediation/profiles/profile-files.json`)
records compressed and original SHA-256 values. Instrumented throughput is not
comparative timing evidence. VM heap counters are not an allocation census.
The final async profile corresponds to matrix 7; the small subsequent allocation
and middleware-failure changes are validated by later complete matrices/tests.

## Remaining measurements and sign-off limits

Every round from both matrices contributes to the combined result. The release
scope difference is +0.030 µs per lifetime; profile scopes are −0.1%. Unmonitored
release fan-out is +0.9%, and profile leaf tasks are +1.1%. Their round ranges
remain visible below. Required initialization guards and actual draining remain
in place; no cancellation request is substituted for completed cleanup.

The exact-binary repeat demonstrates why individual batches must not be treated
as precise speedups: release unmonitored tasks change from −8.3% in matrix 9 to
+2.6% in matrix 10; the all-run result is −3.1%. No favorable batch was selected.

UI engine measurements are less stable than the logic workloads. In the pooled
release data, unmonitored build/raster medians are **+6.9% / +6.4%**; monitored
build/raster medians are **−6.7% / −13.0%**. Monitored build p95 is **3.905 versus
2.832 ms (+37.9%)** when pooled, but the large spike does not repeat: matrix 9
records 4.367 versus 2.834 ms, while matrix 10 records 2.776 versus 2.822 ms.
These slower observations are retained, not relabelled as improvements.

Isolated UI CPU profiles (`performance-remediation/ui-profile-summary.json`)
use the same virtualized list and one `LWatch`, with no concurrent builds/tests.
Samples with Levit frames are 2.8% candidate / 3.0% reference with diagnostics off,
and 4.1% / 3.8% with diagnostics on. They do not establish an additional Levit
hot spot behind the variable engine tails. Sampling cannot prove the absence of
small costs or attribute OS/GPU scheduling. This closes the investigated runtime
hot spots with those measured limits; it does not certify identical UI tails,
cold starts or performance on every target device.

## Profile latency

| Diagnostics | Workload | Reference ms | Candidate ms | Change |
| --- | --- | ---: | ---: | ---: |
| Off | 10,000 observed writes | 0.1350 | 0.1360 | +0.7% |
| Off | 128 computed consumers × 100 writes | 2.8830 | 2.8672 | -0.5% |
| Off | 100 scope lifetimes | 0.2352 | 0.2350 | -0.1% |
| Off | 100 leaf tasks | 0.1620 | 0.1638 | +1.1% |
| Off | Virtualized 1,000-row list: frame wall time | 8.3052 | 8.3027 | -0.0% |
| On | 10,000 observed writes | 42.0355 | 40.9712 | -2.5% |
| On | 128 computed consumers × 100 writes | 57.5105 | 55.8687 | -2.9% |
| On | 100 scope lifetimes | 4.0062 | 3.8695 | -3.4% |
| On | 100 leaf tasks | 0.1590 | 0.1598 | +0.5% |
| On | Virtualized 1,000-row list: frame wall time | 8.2927 | 8.3220 | +0.4% |

## Release latency

| Diagnostics | Workload | Reference ms | Candidate ms | Change |
| --- | --- | ---: | ---: | ---: |
| Off | 10,000 observed writes | 0.1350 | 0.1330 | -1.5% |
| Off | 128 computed consumers × 100 writes | 2.7348 | 2.7595 | +0.9% |
| Off | 100 scope lifetimes | 0.2290 | 0.2320 | +1.3% |
| Off | 100 leaf tasks | 0.1630 | 0.1580 | -3.1% |
| Off | Virtualized 1,000-row list: frame wall time | 8.3120 | 8.3063 | -0.1% |
| On | 10,000 observed writes | 43.1157 | 40.9450 | -5.0% |
| On | 128 computed consumers × 100 writes | 58.9447 | 55.9012 | -5.2% |
| On | 100 scope lifetimes | 4.0853 | 3.9863 | -2.4% |
| On | 100 leaf tasks | 0.1537 | 0.1545 | +0.5% |
| On | Virtualized 1,000-row list: frame wall time | 8.2980 | 8.3340 | +0.4% |

## Flutter engine timings

Pooled medians / nearest-rank p95; 720 matched frames per row. Frame wall time is
display-paced near 8.33 ms, so that number alone cannot establish CPU parity.

| Mode | Diagnostics | Revision | Build median / p95 ms | Raster median / p95 ms |
| --- | --- | --- | ---: | ---: |
| profile | Off | reference | 2.150 / 2.989 | 0.472 / 0.752 |
| profile | Off | candidate | 2.087 / 2.863 | 0.477 / 0.754 |
| profile | On | reference | 2.177 / 2.924 | 0.509 / 0.766 |
| profile | On | candidate | 2.205 / 2.846 | 0.523 / 0.777 |
| release | Off | reference | 2.115 / 3.380 | 0.471 / 0.766 |
| release | Off | candidate | 2.261 / 2.941 | 0.501 / 0.766 |
| release | On | reference | 2.207 / 2.832 | 0.528 / 0.802 |
| release | On | candidate | 2.059 / 3.905 | 0.460 / 0.753 |

## Event volume and variation

Events divided by measured plus actual warmup iterations. Setup/preceding cleanup
may contribute a fractional event. Suppressing an unchanged progress snapshot
is distinct from dropping an event: every run asserts zero transport drops.

| Revision | Workload | Events per iteration |
| --- | --- | ---: |
| reference | notify_10000 | 10000.05 |
| reference | fanout_128_x_100 | 12913.13 |
| reference | scope_lifetime_100 | 800.87 |
| reference | tasks_100 | 0.00 |
| reference | list_1000_frame | 1.00 |
| candidate | notify_10000 | 10000.05 |
| candidate | fanout_128_x_100 | 12913.03 |
| candidate | scope_lifetime_100 | 800.00 |
| candidate | tasks_100 | 0.00 |
| candidate | list_1000_frame | 1.00 |

Diagnostics-off ranges of all 12 round medians, per complete workload:

| Mode | Workload | Reference round range µs | Candidate round range µs |
| --- | --- | ---: | ---: |
| profile | 10,000 observed writes | 134–136 | 134–140 |
| profile | 128 computed consumers × 100 writes | 2857–2937.5 | 2845–3003.5 |
| profile | 100 scope lifetimes | 232–239.5 | 231–242.5 |
| profile | 100 leaf tasks | 156–167 | 162–172 |
| profile | Virtualized 1,000-row list: frame wall time | 8266–8372.5 | 8254.5–8362 |
| release | 10,000 observed writes | 132–146 | 131–137 |
| release | 128 computed consumers × 100 writes | 2663–2921 | 2726.5–2830.5 |
| release | 100 scope lifetimes | 227.5–234.5 | 228.5–245 |
| release | 100 leaf tasks | 150.5–176 | 153.5–162.5 |
| release | Virtualized 1,000-row list: frame wall time | 8272.5–8373.5 | 8260.5–8398 |

## Evidence and reproduction

- All process outcomes (`performance-remediation/replicated-comparison/run.log`),
  summary and raw round medians (`performance-remediation/replicated-comparison/performance-summary.json`),
  engine/event analysis (`performance-remediation/replicated-comparison/performance-analysis.json`).
- The raw-run manifest (`performance-remediation/replicated-comparison/run-files.json`)
  links every original JSON result in `comparison-9/` and `comparison-10/`.
  Build logs remain with the original build matrix; the repeat performs no rebuild. Comparison matrices are never assembled by
  selecting favorable rounds from different runs.
- Build both revisions in profile and release using `lib/release_performance.dart`,
  setting `LEVIT_REFERENCE=539f130` for the reference. Then, with no other builds
  or tests running, execute from the candidate:

```sh
python3 benchmarks/tool/compare_release_performance.py REFERENCE_ROOT OUTPUT
```

See [benchmark documentation](../../../benchmarks/README.md) for fixture and
profiler details. This is one macOS host and a small workload suite, not a mobile,
browser, network or production-workload throughput guarantee. Browser builds and
functional stress tests are separate gates. RSS observations are retained in raw
results and are not a leak/retained-memory study. No publication was performed.
