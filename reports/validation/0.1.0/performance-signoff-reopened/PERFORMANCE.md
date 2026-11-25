# Corrected native performance comparison for Levit 0.1.0

Completed on 2026-11-11: **24 isolated native processes, 12,960 timed samples,
and 4,320 matched Flutter frames**. Profile/release and diagnostics off/on are
measured separately for the approved reference, the original candidate, and the
optimized candidate. All result, delivery, teardown and display checks pass.

## Correction to the previous report

The previous mixed-diagnostics comparison is withdrawn. The legacy monitor's
`close()` releases resources but leaves its middleware registered. Consequently,
later supposedly unmonitored rounds still executed middleware. The earlier
**88.9% notification and 46.9% fan-out speedup claims are invalid**.

The [direct reproduction](recertification/baseline-detach-reproduction.log) shows
attachment surviving legacy `close()` and ending only after `disable()`. Both
adapters now explicitly disable before awaiting close and assert removal from
both reactive and scope registries. The same three-session teardown regression
passes against both runtimes. Every diagnostic state now runs in a fresh process;
no off/on state mixing contributes to these results.

Historical evidence is retained in `superseded-mixed-diagnostics/`.
`recertification/corrected-before/` is an additional rejected probe: individual
runs passed, but the full matrix failed because the display changed from 2× to
1×. Its timings are excluded. The final host positions every window on the
available display with the highest scale factor; geometry, display identity and
refresh rate must match across the entire matrix.

## Reference and experimental controls

The user approved **539f130da148d1a802925d02363996f82ae4a323** because the original
unpublished 0.0.12 archive is missing. This reference excludes those unpublished
changes; baseline differences cannot be assigned solely to one 0.1.0 milestone.

- `reference`: 74 runtime source/manifests verified against Git 539f130.
- `before`: original candidate source manifest
  `4c6b6f64dfac2f0bbd8f32dfe30519e51bfd4ec51652ddc7543334eb3f9da1bf`;
  all 128 package library files remain unchanged. Only the common measurement
  harness/host and corrected monitor adapter are overlaid.
- `candidate`: optimized, functionally revalidated source identified in
  [candidate certification](CANDIDATE.md).

[Source integrity](recertification/final/source-integrity.json) records the
verified inputs and common harness hashes; it includes the exact legacy adapter,
benchmark dependency configuration and lockfile. All three builds use the same
[44 external dependency versions](recertification/final/external-versions.json).
Each raw result records hashes for both the executable and its AOT framework.

Host: Apple M1 Pro, 8 CPU cores, 16 GiB RAM, macOS 26.6.2, Dart 3.12.2 /
Flutter 3.44.8. The final display is 1600 × 1200
physical pixels, 2× ratio, display 1, 120 Hz.
Identical process-scoped activity assertions and visible, unfocused windows keep
frame delivery active; they end with each process. System power settings are
unchanged. No builds or tests run concurrently with measurement. Ordinary desktop
background applications remain running.

Each process runs one diagnostics state for three rounds. A second pass reverses
revision and diagnostic order. Logic workloads have five warmups and 30 measured
samples per round: six round medians / 180 samples per configuration. UI has ten
warmups and 60 measured frames per round: 360 matched frames per configuration.
Results below are medians of round medians; negative change means faster.

Workloads check 10,000 observed writes; 128 computed consumers reading every one
of 100 updates; 100 scope creation/lookup/awaited-cleanup cycles; 100 leaf tasks
through four execution slots; and a mounted virtualized 1,000-row list. Samples
include microtask/stream delivery. Flush after timing verifies that no diagnostic
delivery escaped the measured interval. Drops or incomplete cleanup invalidate
the run. Flutter engine frame IDs exclude warmups and delayed unrelated batches.

Monitoring uses JSON/UTF-8 serialization into a counting sink, with no retained
sink payloads or network/disk IO. Both histories are 10,000 events; the candidate
queue is bounded at 65,536, the legacy queue is unbounded. Stack capture is off;
worker statistics follow diagnostics mode. These are explicit comparison
settings: history and statistics remain disabled by default. The optional task
monitor bridge is absent, so the task workload emits no diagnostic events.

## Confirmed costs, changes and remaining explanations

The fixes reduce release leaf-task latency from
**4.79 to 2.56 µs/task
(-46.7%)**. Diagnostics-enabled notification,
fan-out and scope workloads improve by **31.9%,
31.1% and 36.3%**
respectively versus the original candidate. The tables also retain profile
results and baseline comparisons, including regressions.

| Area | Confirmed issue and implemented change | Remaining interpretation |
| --- | --- | --- |
| Baseline contamination | Legacy close left registered hooks. Explicit disable, registry assertions, three-session regression, separate processes. | Fixed measurement defect; previous speedup claims are withdrawn. |
| Task scheduling | Pending admission repeatedly scanned executions; events were allocated without observers; task callbacks entered a redundant zone. Maintain the pending count, construct events only for observers, and retain one execution zone. | Release remains +63.0% versus reference (2.56 vs 1.57 µs/task). Structured groups, typed outcomes, cancellation/deadline tracking and genuine draining remain. This experiment does not isolate each residual cost. |
| Monitored updates | Envelope creation encoded/decoded ordinary JSON before freezing; synchronous sends incurred artificial future boundaries. Copy/deep-freeze ordinary JSON directly and await only actual asynchronous sends. | Release notifications remain 1.88× and fan-out 1.83× reference. Immutable capture, redaction, bounded buffering and reconnect snapshot maintenance do additional work; these are plausible contributors, not individually profiled causal estimates. |
| Scope monitoring | Scope progress repeatedly normalized already-JSON metadata. Use a dedicated value-free event path while retaining the immutable envelope boundary. Skip progress dispatch immediately when no middleware exists. | Release monitored scopes remain 3.79× reference; the current runtime emits more lifecycle events. Unmonitored scopes remain +49.4% (3.57 vs 2.39 µs/scope). Awaited two-phase cleanup and its accounting are preserved. |
| Notifications without diagnostics | No reactive notification implementation changed in this optimization. | Round medians fluctuate substantially, including between two candidates with identical reactive source. The aggregate delta alone does not establish a stable hot-path regression or speedup. All raw rounds are retained. |
| Computed/UI work | Every computed consumer and measured frame is checked; host/display controls are shared. | Small fan-out/build/raster differences must be read against overlapping round ranges. UI wall latency is display-paced, so it cannot demonstrate runtime performance parity. |

These are improvements to confirmed avoidable overhead, **not elimination of all
baseline performance costs**. The required lifecycle and diagnostic guarantees
are retained. No zero-regression budget was specified; certification records the
remaining costs rather than declaring performance parity.

Tests preserve pending-count correctness under joins, coalescing, replacement and
cancellation; execution-zone disposal guards; custom JSON conversion, cycles and
unsupported values; immutable nested capture; mixed synchronous/asynchronous send
ordering; and close waiting for pending delivery. Five focused monitor tests,
26 task/group/shutdown tests, all 67 benchmark tests, full CI and 100% line coverage
pass on the optimized source.

## Measurements

“Before fixes” uses the original candidate with the corrected measurement harness.
It is not the invalid historical mixed-state measurement.

### Profile workload latency

| Diagnostics | Workload | Reference ms | Before fixes ms | Candidate ms | vs reference | vs before |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Off | 10,000 observed writes | 0.192 | 0.196 | 0.262 | +36.3% | +33.9% |
| Off | 128 computed consumers × 100 writes | 3.119 | 3.057 | 3.085 | -1.1% | +0.9% |
| Off | 100 scope lifetimes | 0.250 | 0.354 | 0.342 | +36.9% | -3.3% |
| Off | 100 leaf tasks | 0.160 | 0.478 | 0.258 | +61.2% | -46.2% |
| Off | Virtualized 1,000-row list: frame wall time | 8.316 | 8.309 | 8.304 | -0.1% | -0.1% |
| On | 10,000 observed writes | 43.215 | 125.817 | 84.958 | +96.6% | -32.5% |
| On | 128 computed consumers × 100 writes | 58.940 | 168.541 | 112.275 | +90.5% | -33.4% |
| On | 100 scope lifetimes | 3.874 | 23.296 | 14.491 | +274.0% | -37.8% |
| On | 100 leaf tasks | 0.164 | 0.486 | 0.267 | +62.7% | -45.0% |
| On | Virtualized 1,000-row list: frame wall time | 8.284 | 8.310 | 8.319 | +0.4% | +0.1% |

### Release workload latency

| Diagnostics | Workload | Reference ms | Before fixes ms | Candidate ms | vs reference | vs before |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Off | 10,000 observed writes | 0.171 | 0.148 | 0.191 | +11.7% | +29.1% |
| Off | 128 computed consumers × 100 writes | 2.846 | 2.953 | 2.904 | +2.0% | -1.6% |
| Off | 100 scope lifetimes | 0.239 | 0.359 | 0.357 | +49.4% | -0.6% |
| Off | 100 leaf tasks | 0.157 | 0.479 | 0.256 | +63.0% | -46.7% |
| Off | Virtualized 1,000-row list: frame wall time | 8.329 | 8.323 | 8.328 | -0.0% | +0.1% |
| On | 10,000 observed writes | 44.010 | 121.671 | 82.815 | +88.2% | -31.9% |
| On | 128 computed consumers × 100 writes | 59.985 | 159.425 | 109.900 | +83.2% | -31.1% |
| On | 100 scope lifetimes | 3.860 | 22.958 | 14.630 | +279.0% | -36.3% |
| On | 100 leaf tasks | 0.157 | 0.476 | 0.266 | +70.1% | -44.1% |
| On | Virtualized 1,000-row list: frame wall time | 8.318 | 8.325 | 8.317 | -0.0% | -0.1% |

### Flutter engine timings

Pooled medians / nearest-rank p95, milliseconds; 360 matched frames per row.

| Mode | Diagnostics | Revision | Build median / p95 | Raster median / p95 |
| --- | --- | --- | ---: | ---: |
| profile | Off | reference | 1.704 / 3.023 | 0.394 / 0.545 |
| profile | Off | before | 1.681 / 2.650 | 0.387 / 0.576 |
| profile | Off | candidate | 1.882 / 2.436 | 0.412 / 0.589 |
| profile | On | reference | 1.982 / 2.378 | 0.420 / 0.580 |
| profile | On | before | 1.812 / 2.366 | 0.406 / 0.569 |
| profile | On | candidate | 1.860 / 2.425 | 0.429 / 0.515 |
| release | Off | reference | 1.739 / 2.379 | 0.371 / 0.529 |
| release | Off | before | 1.710 / 2.349 | 0.402 / 0.567 |
| release | Off | candidate | 1.659 / 2.299 | 0.407 / 0.544 |
| release | On | reference | 1.927 / 2.339 | 0.392 / 0.532 |
| release | On | before | 1.855 / 2.390 | 0.374 / 0.491 |
| release | On | candidate | 1.917 / 2.436 | 0.400 / 0.513 |

### Event volume and round variation

Events per workload iteration (including proportional warmups; setup/preceding cleanup can add a fractional count):

| Revision | Workload | Events per iteration |
| --- | --- | ---: |
| reference | notify_10000 | 10000.1 |
| reference | fanout_128_x_100 | 12914.6 |
| reference | scope_lifetime_100 | 803.657 |
| reference | tasks_100 | 0 |
| reference | list_1000_frame | 1 |
| before | notify_10000 | 10000.1 |
| before | fanout_128_x_100 | 12914.6 |
| before | scope_lifetime_100 | 1200 |
| before | tasks_100 | 0 |
| before | list_1000_frame | 1 |
| candidate | notify_10000 | 10000.1 |
| candidate | fanout_128_x_100 | 12914.6 |
| candidate | scope_lifetime_100 | 1200 |
| candidate | tasks_100 | 0 |
| candidate | list_1000_frame | 1 |

Diagnostics-off round ranges, in microseconds per complete workload (six round medians per cell):

| Mode | Workload | Reference range | Before range | Candidate range |
| --- | --- | ---: | ---: | ---: |
| profile | notify_10000 | 138–249 | 139–383 | 143.5–395 |
| profile | fanout_128_x_100 | 2978–3265 | 2919–3165 | 3033–3140 |
| profile | scope_lifetime_100 | 244–257 | 350–404.5 | 335.5–352.5 |
| profile | tasks_100 | 158–170 | 469–492.5 | 252–268 |
| profile | list_1000_frame | 8234.5–8336.5 | 8248.5–8328.5 | 8275–8333.5 |
| release | notify_10000 | 141–375 | 145–289.5 | 144–376 |
| release | fanout_128_x_100 | 2746.5–2963 | 2830–3138 | 2837.5–3046.5 |
| release | scope_lifetime_100 | 234–247.5 | 336.5–407 | 338–360 |
| release | tasks_100 | 154–160.5 | 456.5–498.5 | 247–262 |
| release | list_1000_frame | 8258.5–8371.5 | 8306.5–8342.5 | 8312.5–8343.5 |

## Evidence, reproduction and limits

- [All 24 process outcomes](recertification/final/performance-runs.log),
  [workload summary and raw round medians](recertification/final/performance-summary.json),
  [engine/event analysis](recertification/final/performance-analysis.json).
- Raw `performance-<revision>-<mode>-<diagnostics>-<repeat>.json` files and native
  build logs are in `recertification/final/`. No failed/provisional sample is
  silently substituted into this matrix.
- Build all three roots in profile and release as described in
  [the benchmark README](../../../benchmarks/README.md), using `LEVIT_REFERENCE`
  values `539f130`, `before`, and `candidate`. Then run from the candidate:

```sh
python3 benchmarks/tool/compare_release_performance.py REFERENCE_ROOT OUTPUT BEFORE_ROOT
```

This is one native macOS host, not a mobile/browser throughput guarantee. Browser
checks establish compilation separately. Candidate RSS observations range from
99.8 to 166.7 MiB; this is
not retained-memory or leak evidence. The counting transport does not measure
network/IO latency. Remaining cost explanations are code-informed hypotheses
unless an explicit test or controlled before/after change above establishes them.
The approved baseline substitution remains explicit; nothing here compares
against the missing unpublished archive.
