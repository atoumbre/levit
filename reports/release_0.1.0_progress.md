# Levit 0.1.0 implementation progress

Generated run artifacts were removed during cleanup on 2026-11-24. Historical artifact paths refer to Git commit `bd1a095`.


This is a work log, not release certification. The approved release includes
all eight revised milestones in the [0.1.0 plan](release_0.1.0_plan.md).
Publication is a separate action.

**Approved M7 revision:** persistence has moved to the independent
[ecosystem roadmap](ecosystem_roadmap.md) and no longer blocks 0.1.0. The user has
authorized the borrowing ValueListenable adapter and countdown correction in the
main repository. Revised M7 is complete and validated; persistence is still planned
separately and has not been implemented.

## Family replacement (0.1.0)

- [x] Freeze and verify pre-redesign source and lockfiles; map existing regressions to successors.
- [x] Per-key map observation and borrowing entries.
- [x] Per-position list observation and borrowing entries.
- [x] Single-producer resource and exclusive ownership.
- [x] Task-backed async map and bounded retention.
- [x] Consumer migration and family removal.
- [ ] Candidate comparison, coverage and certification.

Baseline manifest and SDKs (`validation/0.1.0/collection-redesign/baseline.json`).
The review passed 17 core, 12 query-kit and 4 catalog tests. Single-producer
refresh, failure, stream and shutdown tests migrate to LxResource; keyed identity,
retention, freshness and task cancellation tests to LevitAsyncMap. Mounted
builder and borrowing adapter tests exercise their public read-only surfaces.
All four reproduced defects now have passing permanent regressions: dual
ownership, unreadable replacement, self-join during drain and zero-grace fetch.
Core: 562 passing tests, including sparse map/list reads, missing and nullable
addresses, partial writes, equality changes, nested batching and channel release.
The kit's 19 async-map tests, 11 ownership tests, 9 Flutter resource/adapter
tests and 5 catalog tests pass. An isolated favorite write rebuilt one of six
mounted catalog rows, with the saving indicator unchanged. The core-only stream
example ran across replacement. The discarded-future rule passes its 10 tests.
The removed family APIs have no compatibility exports.

The [November 14 candidate record](validation/0.1.0/collection-redesign/CANDIDATE.md)
documents delayed activation in both computed modes, diagnostic redaction,
browser builds, inspector packaging and ten publication dry-runs. Its coverage
gate passed all 7,009 executable lines. Its first focused comparison exposed
slower shifts and churn. Its native attempt ended with zero complete reports.

### List shifts and subscription churn

- [x] Profile the two regressions on the archived candidate. The shift profile identified repeated channel lookup, batch sorting and notification costs. The churn profile attributed 466 of 1,917 self samples to formatting names. Shift samples (`validation/0.1.0/collection-performance/shift-before.json`) · Churn samples (`validation/0.1.0/collection-performance/churn-before.json`)
- [x] Verify the historical Flutter entrypoint. The archived reference profile app emitted the interactive profiler’s ready marker. Rebuilding it for the release workload produced a complete 15-round preflight with real frames.
- [x] Verify cleanup and sparse updates. Aggregate CI passed, the reactive package reached 100% coverage, all 38 stress tests passed, and the mounted catalog rebuilt one of six favorite rows. CI (`validation/0.1.0/collection-performance/ci.log`) · Catalog (`validation/0.1.0/collection-performance/catalog.log`) · Stress (`validation/0.1.0/collection-performance/stress.log`)
- [x] Rerun the unchanged AOT workloads. Across eight balanced rounds, list shifts took 31.8% less time and subscription churn took 35.7% less than pre-redesign. Against 539f130 the reductions were 71.2% and 7.5%. Sparse map and index writes retained their evaluation counts and took 97.8% and 98.1% less time than pre-redesign. All samples (`validation/0.1.0/collection-performance/addresses-raw.json`)
- [x] Pass the full 100% coverage gate, 7,099/7,099 lines across 11 packages. Coverage (`validation/0.1.0/collection-performance/coverage.log`)
- [x] Complete all 24 native comparisons on the same 120 Hz display, in profile and release with diagnostics off and on. The run validated 4,320 engine frames. Unmonitored release fan-out took 37.3% less time than pre-redesign and 74.5% less than 539f130. Median frame cadence stayed within 0.2% of pre-redesign. [Comparison and profiles](validation/0.1.0/collection-performance/PERFORMANCE.md)
- [ ] Overall performance sign-off remains open. The unmonitored release task workload took 9.3% longer than 539f130. Monitored release scope lifetimes took 3.3% longer than pre-redesign and 4.0% longer than 539f130. Monitored profile fan-out took 3.1% longer than pre-redesign. These rows ran slower in both paired launches against the stated reference. Paired measurements (`validation/0.1.0/collection-performance/native-pairs.json`)

## Published-release comparison (2026-11-13)

- [x] Verify the live pub.dev baseline: coordinated runtime release **0.0.11**,
  published August 6. Download and verify archive checksums. Its 58 runtime Dart
  files and two packaged example library files exactly match `539f130`; no
  reference-only runtime library files are present.
- [x] Build separate published/current snapshots with identical timed workloads
  and non-Levit dependency locks. Preserve compatibility-only teardown/ownership
  patches; leave runtime sources and workspace dependencies unchanged.
- [x] Pass 51 computed-mode/delivery contract tests on each snapshot, plus
  fatal-info analysis of the current benchmark package.
- [x] Compare all six computed workloads in both modes plus mutation, warm DI
  and four UI workloads, using four balanced revision pairs per case:
  **144/144 cases pass, 7,200 samples and 1,600 matched engine frames**.
- [x] Record raw results, frame metrics, limitations and release/API differences;
  archive both measured source snapshots. Dynamic diamond/fan-in/fan-out and
  both chain modes improve in every p50 pair. Static async and progress rendering
  are slower in every p50 pair; other static/DI/UI signals remain mixed.
- [ ] Attribute and confirm the remaining slower paths before overall performance
  sign-off. This comparison does not recertify the candidate or authorize publication.

[Published-release comparison and evidence](validation/0.1.0/2026-11-13-published-comparison/COMPARISON.md)
include every paired change and background-load limitations. Runtime sources,
workspace dependencies and the normal interactive app binary are unchanged.

## Static/dynamic computed comparison (2026-11-12)

- [x] Add explicit tracking-mode variants for all six computed app workloads,
  preserving production sizes, observer wiring, cleanup and dashboard defaults.
  Runtime package sources are unchanged.
- [x] Validate both modes; all 119 benchmark-package tests, formatting and
  fatal-info analysis pass.
- [x] Run one release binary in four balanced pairs, retaining raw samples,
  source/binary identities and per-process p50/p95 results. Repeat with each
  workload isolated after observing substantial suite-order variation:
  **96 valid cases / 4,800 samples** across both experiments.
- [x] Document both experiments, background-load limits and per-pair variability;
  restore the interactive release app. Isolated static p50 is lower for fan-in,
  diamond and batching in every pair; fan-out is mixed. Static chain and async
  p50 are higher in every isolated pair. No blanket static-mode switch is justified.

[Comparison, interpretation and raw evidence](validation/0.1.0/2026-11-12-computed-modes/COMPARISON.md)
retain the noisy suite as well as the isolated follow-up. Runtime sources and
normal dashboard defaults are unchanged.

This compares dependency-tracking modes on the current runtime. It does not
close the remaining performance sign-off or recertify the archived candidate.

## Grid and computed profiling follow-up (2026-11-12)

**Computed remediation is complete; overall performance sign-off remains open.**
The comparison baseline is the preserved starting checkout at
`/private/tmp/levit-20261112-before-vdalnd4n`. This is a matched methodology-2 app
comparison, not a new `539f130` certification. The earlier certificate remains
tied to its archived source. Nothing has been published.

- [x] Preserve starting source, locks and Git status; verify unchanged benchmark
  workloads and native host. No original file is missing.
- [x] Profile production-size fan-in/fan-out and keyed grid churn. Repeated
  dependency-set reconciliation dominates computed costs; Flutter layout
  dominates grid CPU. No grid-specific runtime defect is established.
- [x] Reuse verified dependency order with dynamic fallback, retain depth checks,
  release trackers on failures, and prevent resubscription after closure during
  eager notification. Keep ordinary computed reads compact and optional graph
  diagnostics separate. No workload was switched to `staticDeps`.
- [x] Resolve the deep-chain regression found in the first implementation; the
  final compact getter improves the unchanged chain in both release pairs.
- [x] Validate the real mounted catalog workflow: search, pagination, refresh,
  optimistic rollback and awaited unmount during an outstanding request.
- [x] Repeat the final full comparison in reversed revision order: **240 cases,
  12,000 samples and 4,000 matched frames**. Fan-in medians are **63–82% lower**,
  fan-out **21–38% lower**, and chain **8–20% lower** in the two matched pairs.
- [x] Repeat the unchanged grid alone: **20 cases / 1,000 matched frames**.
  Full-suite grid build medians are about 2% lower; isolated results move in
  opposite directions. No grid speedup is claimed and its workload is unchanged.
- [x] Pass final formatting, fatal-info analysis and aggregate CI; retain **100%
  coverage across 11 packages (6,767/6,767 lines)**, all 104 benchmark tests,
  38 stress tests, browser runtime/catalog builds and native builds. Restore
  normal interactive profile/release apps stamped with the measured source ID.
- [ ] Attribute the remaining full-suite list/progress/DI timing signals before
  closing overall performance sign-off. They ran higher in this comparison;
  their unchanged paths and variable controls do not establish a cause yet.

[Results, limitations and raw evidence](validation/0.1.0/2026-11-12-app-performance/PERFORMANCE.md)
include every workload, source digests, rejected experiments and the exact patch.
The catalog validation establishes correctness, not an end-to-end app speedup.

## Benchmark app follow-up (2026-11-11)

This follows the frozen candidate certification below. The archived certificate
and native reference-comparison evidence still describe their exact source
snapshot; they do not certify these subsequent benchmark-app changes. Runtime
packages and `release_performance.dart` are unchanged by this follow-up.

- [x] Time completed fan-in computations and every fan-out consumer, and wait for
  every rapid-mutation notification before stopping the stopwatch.
- [x] Consume every diamond/chain update and the batch demo's final aggregate;
  identify RxDart, ValueNotifier and custom-map substitutes accurately.
- [x] Correct the virtualized-list, keyed-grid, nested-leaf and progress-bar
  workloads; distinguish frame-wait wall time from matched build/raster timings.
- [x] Export raw JSON samples, record refresh/source metadata, document methodology
  2 and mark earlier app measurements as non-comparable.
- [x] Complete permanent regressions and the full benchmark suite: **104 tests
  pass**, including 37 new completion, UI lifecycle/surface, and reporting checks.
- [x] Pass fatal-info analysis and formatting (34 Dart files, zero changes),
  native production-size smoke validation (**60 cases, 120 wall samples, 40
  matched engine frames**) and the normal interactive macOS release build.
  [Validation evidence](validation/0.1.0/benchmark-app-fix/VALIDATION.md) records
  correctness checks only; the two-sample smoke is not a performance comparison.
- [x] Add full written assessments beside OK/Error in the dashboard and text
  reports; include the assessment in JSON and preserve failure details. These
  describe run validity rather than speed. Presentation follow-up: [40 focused
  tests pass](validation/0.1.0/benchmark-status/tests.log), [fatal-info analysis
  passes](validation/0.1.0/benchmark-status/analyze.log), five edited Dart files
  pass formatting, and the interactive release app is rebuilt (`validation/0.1.0/benchmark-status/build.log`).
  This later presentation change leaves workload timing unchanged and does not
  update the earlier archived candidate or benchmark-fix source manifest.

## Baseline

- Existing checkout: commit `539f130` plus the unpublished 0.0.12 changes.
- Originally preserved 750 source files, SHA-256 manifest, and Git status in
  `/private/tmp/levit-0.1.0-baseline-20260915-102208` before implementation.
  Rechecked on 2026-10-16: that temporary directory is no longer present.
  The working tree remains intact. On 2026-11-11 the user explicitly approved
  committed revision `539f130da148d1a802925d02363996f82ae4a323` as the performance
  reference. It excludes the missing unpublished 0.0.12 changes; it is not a
  reconstruction of that archive or the modified candidate checkout.
- Target toolchain: Dart 3.12.2 / Flutter 3.44.8.

## Milestones

Checklist updated 2026-11-11. Checked substeps record completed implementation or
recorded validation. A milestone stays unchecked until its remaining integration,
documentation and acceptance work is complete.

- [x] M1: Awaited resource disposal, owned scopes, serialized widget replacement.
  - [x] Implement awaitable reactive and owner cleanup with cancellation/draining.
  - [x] Track pending initialization and support explicit ownership disposers and async disposal callbacks.
  - [x] Implement parent-owned child scopes and awaited factory-instance release.
  - [x] Make loop stopping await active work and preserve manual pause intent.
  - [x] Implement serialized Flutter scope replacement and its lifecycle controller.
  - [x] Complete integration, failure-path validation and documentation sign-off.
- [x] M2: Store identity/overrides, readable state, testing boundaries.
  - [x] Key stores by definition identity and variant; implement typed lookup and scope overrides.
  - [x] Propagate construction/type errors through optional lookup.
  - [x] Introduce observation-only `LxReadable<T>` interfaces.
  - [x] Add immutable scope descriptions and isolated testing entry points.
  - [x] Complete integration, documentation and acceptance sign-off.
- [x] M3: Direct API removals and Nexus command history.
  - [x] Remove obsolete APIs and migrate repository code consumers.
  - [x] Replace Nexus runtime history with bounded application-owned commands.
  - [x] Implement atomic execute/undo/redo, drag grouping and remote-history reset.
  - [x] Synchronize inverse operations, including idempotent `node_delete`.
  - [x] Add and run the two-client WebSocket undo regression (earlier validation).
  - [x] Finish documentation migration and release-wide integration validation.
- [x] M4: Structured tasks, typed outcomes, bounded/fair scheduling and retries.
  - [x] Implement task groups, both failure policies and descendant draining.
  - [x] Add typed task outcomes and preserve successful nullable values.
  - [x] Implement inherited deadlines, bounded pending submissions and weighted scheduling.
  - [x] Replace retry flags with explicit classified, capped retry policies.
  - [x] Propagate cancellation into isolates and expose task-tree metadata.
  - [x] Pass the structured-task regressions in the 2026-10-16 focused run.
  - [x] Complete full integration, documentation and acceptance sign-off.
- [x] M5: Stable refreshable families and task-backed queries.
  - [x] Implement stable typed family handles with refresh, invalidation and bounded inactive retention.
  - [x] Implement task-backed query families with deduplication, freshness, retry and cancellation.
  - [x] Preserve explicit previous-data presence, including successful `null` values.
  - [x] Give status builders the full waiting/error status and migrate existing callbacks.
  - [x] Pass query, family and retained-data regressions in the 2026-10-16 focused run.
  - [x] Add mounted Flutter refresh coverage and finish integration validation.
  - [x] Add searchable pagination and optimistic rollback application examples.
  - [x] Complete DartDoc, package READMEs and migration documentation.
- [x] M6: Awaited/redacted monitoring and standalone local inspector.
  - [x] Await monitor attachment/replacement, flush and detach, including cleanup failure paths.
  - [x] Freeze immutable redacted envelopes before buffering; bound queues/history and account for drops.
  - [x] Default worker statistics/history off and opt in for inspector sessions.
  - [x] Keep protocol/runtime imports browser compatible and isolate file transport behind the IO entry point.
  - [x] Add initialization/closing progress, ownership metadata and an optional application task adapter.
  - [x] Add the publishable local inspector CLI and private Flutter web UI at 0.1.0.
  - [x] Bundle local web runtime/fonts; retain loopback port 9200 and producer `/ws`.
  - [x] Implement session selection, ownership/reactions, update details, tasks, cleanup, filtering and redacted export.
  - [x] Validate browser support, reconnect accuracy, bounded retention and packaged startup.
  - [x] Update DartDoc, package READMEs, Nexus integration and cumulative migration guidance.
  - [x] Run relevant complete suites, fatal-info analysis, release web build and CLI publication dry-run.
- [x] M7 (revised): Borrowing Flutter interoperability and elapsed countdowns.
  - [x] Move the complete persistence scope and acceptance criteria to an independent ecosystem roadmap.
  - [x] Update the 0.1.0 objective, package boundary and release gates to match the approved revision.
  - [x] Implement a borrowing ValueListenable adapter with listener-based subscription ownership.
  - [x] Correct countdowns to use elapsed time with precise pause/resume and awaited cleanup.
  - [x] Complete the runnable example, DartDoc, READMEs and migration guidance.
  - [x] Pass relevant full suites, fatal-info analysis and focused acceptance tests.
- [x] M8: Publishable lint tooling, runnable examples and cumulative migration.
  - [x] Create the cumulative `MIGRATION_0.1.0.md` draft covering M1–M4 and earlier unpublished changes.
  - [x] Finish publishable lint configuration, focused rules and valid/invalid pattern tests.
  - [x] Complete runnable examples, onboarding and architecture guidance.
  - [x] Finish the cumulative migration guide and advanced-feature documentation.
  - [x] Coordinate 0.1.0 package versions, SDK minimums and package/test discovery.

## Coverage and M1–M4 sign-off follow-up

The 100% threshold and existing exclusions remain unchanged. New tests assert
lifetime/error/observation behavior; the earlier M8 results remain historical.

- [x] `levit_scope`: 100% (719/719 lines), including late initialization failure,
  aggregate cleanup, observer isolation, aliases and inherited factory release.
- [x] `levit_dart_core`: 100% (480/480 lines), including capture errors,
  expired capture guards, custom owners, adapters and test teardown reporting.
- [x] `levit_reactive`: 100% (1770/1770 lines), including middleware failure, combined producer
  cleanup errors, family retirement/refresh failure and retained observations.
- [x] `levit_dart`: 100% (1327/1327 lines), including group boundaries,
  deadlines, cache IO cancellation, nullable retained results and query shutdown.
- [x] `levit_flutter_core`: 100% (637/637 lines), including reentrant
  initialization/replacement, listener-triggered close, failure/retry and adapters.
- [x] `levit_monitor`: 100% (877/877 lines), including transport failures,
  cancellation draining, queue overflow, snapshot bounds and frozen severity.
- [x] `levit_devtools`: 100% (232/232 lines), including relay bounds,
  protocol rejection, asset failures, packaged assets and awaited shutdown.
- [x] `levit_devtools_ui`: 100% (244/244 lines), including session selection,
  stale connection failures, bounded timelines, filtering, export and ancestry cycles.
- [x] Review M1–M4 DartDoc/READMEs and cumulative migration; correct stale factory
  permanence and task-group guidance and record the permanent acceptance matrix.
- [x] Rerun the unchanged aggregate 100% gate across all 11 packages:
  **6,508/6,508 executable lines**, including the latest M1 fixes
  (`signoff-aggregate-coverage.log`, exit 0).
- [x] Finish M1–M4 acceptance matrix, documentation and integration sign-off:
  final native-plugin, fatal-info analysis, Dart and Flutter CI passes, including
  Nexus command history and two-client WebSocket convergence (`signoff-ci.log`).

Found and fixed: registration cleanup collected initialization errors before
late-adopted work finished. It now drains that work to completion before collecting
failures. Evidence: `validation/0.1.0/signoff-scope-regressions.log` and
`signoff-scope-coverage.log`.

Also fixed: Flutter now adopts initialization before invoking user callbacks,
and listener-triggered shutdown cannot complete before its cleanup pump. The
full Flutter core suite passes (`signoff-flutter-coverage.log`); the focused
lifecycle regressions pass in `signoff-flutter-regressions.log`.

Reactive cleanup now completes all release phases even if disposal middleware
throws, and aggregates producer and observation errors. WebSocket transport owns
subscription cancellation explicitly so cancellation failures remain part of its
awaited shutdown. Evidence: `signoff-reactive-dart-coverage.log`,
`signoff-monitor-coverage.log`, and their focused regression logs.

Inspector fixes: capacity rejection uses a Dart-supported WebSocket status;
streaming HTTP failures retain their original error and finish cleanup; stale
handshake failures cannot disconnect a newer connection; cyclic ancestry remains
visible. Both inspector packages pass `signoff-inspector-all-coverage.log`.

M1 review also found missing initialization execution guards and an early factory
release path that skipped cancellation/draining. `runInitialization` now admits
external setup before callbacks and guards self-disposal; DI/controller/store
initializers and widget scopes share that protection. Delete/reset/release reject
self-disposal before mutating registrations. Early releases drain work and remain
tracked through scope closure, including concurrent releases. Focused regressions
pass, including release failure propagation through scope closure and execution
guards retained during early release. The aggregate coverage run includes these
last M1 changes. Counts above describe that passing run. See the
[acceptance matrix](validation/0.1.0/SIGNOFF_M1_M4.md).

## Release gates

### Reopened performance sign-off completed

The user reopened performance sign-off on 2026-11-11. The profiled hot paths and
newly discovered cleanup failures are fixed, and the current candidate passes
its complete validation. **Nothing has been published.** Historical source and
all intermediate evidence are retained.

- [x] Reopen sign-off and withdraw the prior release-ready claim while regressions
  are investigated against the user-approved committed `539f130` reference.
- [x] Capture native CPU profiles for tasks, scopes, monitored updates and UI on
  both revisions. Match the final scope profiler to the timed async disposer.
  Retain original VM responses, compression hashes and profiling limitations.
- [x] Remove timestamp reparsing, repeated capture copies and eager expansion of
  ownership metadata. Preserve immutable/redacted events, custom serialization,
  bounded queues, self-contained progress records, replay and reconnect state.
- [x] Remove eager task outcomes, unused cancellation futures and redundant
  no-cache/runner continuations. Preserve async admission, nullable success,
  cancellation reasons, task-group identity and actual descendant completion.
- [x] Make optional scope bookkeeping, aliases and ancestor caches lazy; reduce
  cleanup continuations and temporary cancellation collections. Preserve stable
  disposal futures, initialization guards, LIFO release and failure aggregation.
- [x] Fix the closing-scope self-disposal gap: retiring registrations retain their
  task execution guards. The permanent regression fails before the fix and passes
  afterwards.
- [x] Fix deletion/disposal middleware failures skipping later observers/cleanup
  or masking earlier errors. Cover synchronous/async disposal, delete/reset and
  non-owning aliases; update DartDoc, README and migration guidance.
- [x] Correct short-burst instability identically in both harnesses: at least five
  iterations and 500 ms warmup per logic workload. Keep cold-start claims outside
  the warm steady-state measurements. Exclude comparison 6 because test
  compilation overlapped its timing; retain that exclusion explicitly.
- [x] Complete two full matrices using the same executables/AOT: **32 isolated
  processes, 17,280 samples and 5,760 matched frames**, with profile/release,
  diagnostics off/on and reversed-order passes. No builds/tests/profilers run
  concurrently with these measurements; every delivery/cleanup check passes.
- [x] Record the complete combined result, including slower cells. Release tasks
  are −3.1%; monitored notification/fan-out/scope workloads are −5.0% / −5.2% /
  −2.4%. Release scopes without diagnostics remain **+1.3% (+0.030 µs each)**;
  profile scopes are −0.1%. Small positive logic deltas and variable UI medians/
  tails are explicit in the report. UI profiling did not establish an additional
  Levit hot spot. This closes the investigated regressions, not a universal
  performance-parity claim.
- [x] Pass all frozen-candidate gates: formatting (587 Dart files, zero changes),
  aggregate CI/fatal-info analysis, **6,747/6,747 covered lines across 11 packages**,
  stress, 67 benchmark tests, five browser builds and ten publication dry-runs.
  The coverage threshold/exclusions remain unchanged.
- [x] Verify installed inspector startup/shutdown in an isolated cache with only
  Dart on PATH. Reproduce all 35 bundled assets independently; verify 112 local
  package roots, all ten 0.1.0 versions and all 23 unchanged dependency locks.
- [x] Archive and verify the new source/dependency manifests, source archive and
  validation evidence; refresh candidate certification without publishing.

Current evidence: [performance report](validation/0.1.0/PERFORMANCE.md),
frozen validation (`validation/0.1.0/performance-remediation/validation-status.json`),
exact-binary replication (`validation/0.1.0/performance-remediation/repeat-status.json`),
[candidate certificate](validation/0.1.0/CANDIDATE.md).

### Historical corrected comparison and recertification

The prior performance sign-off is withdrawn: the reference monitor's `close()`
did not unregister middleware, contaminating later rounds. The previous source archive and
historical evidence are retained. The corrected three-revision comparison and
optimized-candidate checks below supersede that sign-off.

- [x] Fix baseline teardown; assert both middleware hooks are removed after close.
  The same three-session regression passes on the reference and candidate.
- [x] Isolate diagnostics on/off in separate processes and measure the unchanged
  candidate alongside the reference and optimized candidate in the same matrix.
- [x] Implement targeted task, monitor and scope optimizations with permanent
  correctness regressions. Five monitor tests and 26 task/group/shutdown tests
  pass; full Dart/Flutter CI, 67 benchmark tests and stress suites pass.
  Release task latency improves 46.7%; monitored notifications, fan-out and
  scopes improve 31.9%, 31.1% and 36.3% against the original candidate.
- [x] Repeat controlled profile/release comparisons: 24 processes, 12,960 timed
  samples and 4,320 matched frames pass. Residual baseline costs remain explicit:
  release tasks +63%, scopes +49%, monitored workloads 1.8–3.8×. Small notification
  and UI deltas are inconclusive given round variation. Invalid historical
  speedups are withdrawn in the [corrected report](validation/0.1.0/PERFORMANCE.md).
- [x] Validate the revised isolated candidate: 6,524/6,524 covered lines, full CI,
  format/analysis, stress, 67 benchmark tests, all five browser builds, ten
  publication dry-runs and installed inspector startup pass. Browser builds ran
  from matching working source; inspector assets reproduce in the isolated snapshot.
- [x] Archive fresh source/dependency digests and recertify without publishing.
  Every archived source/lock byte is verified; all 23 dependency locks match the
  original candidate. See the [new certificate](validation/0.1.0/CANDIDATE.md).

### Historical candidate follow-up (superseded)

- [x] Recheck baseline recovery: no original archive, stash or worktree found;
  the existing M8 snapshot is a later implementation and cannot stand in for it.
  The user approved commit `539f130` as the comparison reference on 2026-11-11.
  It excludes the missing unpublished 0.0.12 changes; this is an explicit baseline
  change, not recovery of the original archive.
- [x] Correct benchmark cleanup: await Levit teardown, unmount after failures,
  and reject results when teardown fails. Six cleanup/frame-matching regressions
  pass. Native timings match measured engine frame IDs and exclude delayed
  warmup batches; fan-out checks every consumer update.
- [x] Resolve all 22 packages together in an isolated candidate. Normalize root
  script formatting with a freshly resolved Dart 3.12 package configuration;
  the clean snapshot passes formatting without changes.
- [x] Record native profile/release measurements with diagnostics off/on and
  compare against the agreed reference. 24 isolated processes, 12,960 samples and 4,320
  matched frames pass. Regressions and host controls are documented in
  [the performance report](validation/0.1.0/PERFORMANCE.md).
- [x] Validate a clean source snapshot with coordinated local dependencies,
  formatting, fatal-info analysis, CI, 100% coverage and browser builds.
  - [x] Isolated native-plugin, fatal-info analysis, Dart and Flutter CI passes,
    including packaged inspector startup (`candidate-ci.log`). The dependency
    audit verifies every local reference stays inside the snapshot and all 10
    publishable package versions are 0.1.0 (`candidate-package-graph.json`).
  - [x] Final coverage is **6,524/6,524 lines across 11 packages**, with unchanged
    threshold/exclusions (`candidate-coverage.log`); all five browser targets pass
    and bundled inspector assets reproduce byte for byte.
- [x] Run all publication dry-runs and verify packaged inspector startup.
  - [x] All 10 publishable packages pass `--dry-run` from the clean snapshot;
    nothing was published (`candidate-publish-dry-run.log`).
- [x] The complete benchmark harness passes all 67 tests in the clean snapshot,
  including the six new cleanup/frame-timing regressions (`candidate-benchmarks.log`).
- [x] Record candidate source/archive digests, migration checks, results and
  limitations; certify the candidate without publishing.

### Frozen candidate gates (before benchmark app follow-up)

- [x] Formatting and fatal-info analysis: 587 Dart files, zero formatting changes;
  root/package analysis and native lint-plugin loading pass.
- [x] Dart, Flutter, browser and packaged-tool tests: full aggregate suites, all
  five browser targets and installed inspector startup/shutdown pass.
- [x] Aggregate CI and the existing 100% coverage gate: **6,747/6,747 lines across
  11 packages**, with threshold and exclusions unchanged.
- [x] Stress, all 67 benchmark tests, and replicated native profile/release
  comparison with diagnostics isolated off/on against approved `539f130`.
- [x] Clean candidate snapshot, verified source/archive/dependency digests,
  migration checks, reproducible assets and all ten publication dry-runs.

## Status checked 2026-11-11

All eight revised milestones are complete, and the archived candidate was validated
and certified without publication. The later benchmark-app follow-up above is
validated separately and is not part of that archived source digest. The reopened performance work closes the profiled
hot paths with the small remaining costs and UI variability explicitly recorded.
See [candidate certification](validation/0.1.0/CANDIDATE.md) for exact source and
archive identities, and [performance results](validation/0.1.0/PERFORMANCE.md) for
all 32 final runs and their limits. The missing unpublished baseline is excluded
under the user's approved reference change. The original dirty working tree and
historical archives remain intact; no publication, commit or tag was performed.

Milestone checkboxes mean completed implementation, integration, documentation
and acceptance checks. Publication remains a separate user action.

| Milestone | Current state |
| --- | --- |
| M1 | Complete: awaited two-phase cleanup, owned scopes, initialization/self-disposal guards, factory release, loops and serialized Flutter replacement. Failure-path regressions, complete suites, migration and API documentation pass review. |
| M2 | Complete: identity-keyed stores, typed local/ancestor access and overrides, observation-only interfaces, immutable descriptions and isolated test scopes. Compile-time API checks and runtime/widget acceptance pass. |
| M3 | Complete: direct removals and repository migration; bounded atomic Nexus commands and synchronized inverse operations. Removal scan, migration review, history tests and real two-client WebSocket convergence pass. |
| M4 | Complete: structured groups, typed outcomes, bounded fair scheduling, deadlines, classified retries, isolate cancellation and task metadata. Acceptance covers single-slot coordination, both policies, successful null and descendant cleanup; full integration passes. |
| M5 | Complete: stable families/queries, retained nullable status, mounted Flutter refresh regressions, searchable pagination and optimistic rollback example, API documentation and migration guidance. Relevant full suites and catalog browser build pass. |
| M6 | Complete: awaited/redacted/bounded monitoring, lifecycle progress, optional task bridge, publishable CLI and private web UI. Relevant suites, browser integration, packaged startup and CLI dry-run pass. |
| M7 | Complete under the approved revision: borrowing ValueListenable adapter, elapsed countdowns with precise pause and awaited cleanup, runnable example and documentation. Relevant full suites, workspace analysis and browser build pass. Persistence remains planned in the ecosystem roadmap. |
| M8 | Complete: publishable native lints (23 tests and real consumer loading), six workflow/session example tests, onboarding/architecture/migration, coordinated versions and CI discovery. Final integration, packaging, profiled-performance sign-off and candidate certification pass; remaining measured limits are explicit in the current release evidence. |

### M1–M4 sign-off recorded 2026-11-11

All remaining milestone checkboxes are complete. The unchanged aggregate coverage
gate passes at **100% (6,508/6,508 lines across 11 packages)**. Native lint-plugin
loading, workspace fatal-info analysis, all Dart/Flutter suites, five browser
targets, stress suites and all 60 benchmark harness tests pass after the final
ownership and initialization fixes. See the
[acceptance matrix and validation evidence](validation/0.1.0/SIGNOFF_M1_M4.md)
and [current package coverage](packages_test_coverage.md).

The M8 figures below are historical checkpoints; their old coverage and M1–M4
limitations are superseded by this sign-off. The final certification above now
also closes the performance/candidate gates against the user-approved `539f130`
reference; the missing unpublished baseline remains explicitly documented.

### M8 validation recorded 2026-11-11

- All M8 implementation checkboxes are complete. `levit_lints` is publishable at
  0.1.0 with native plugin configuration, three focused rules and **23 passing
  tests**. A real consuming package validates super delegation plus facade,
  owner and worker cleanup diagnostics and an accepted awaited pattern.
- Save/upload and session-replacement examples: **6 tests passed**, including
  actual buttons, child cancellation/drain, root isolation, rapid replacement,
  ancestor reuse and local typed widget overrides. Catalog pagination/rollback
  remains included in aggregate CI.
- Onboarding now follows scopes → owners → state → widgets. Advanced helpers,
  architecture/proposal dispositions and the cumulative migration guide describe
  current contracts and the approved ecosystem boundary.
- **22 packages bootstrapped together**, with runtime/lint/inspector versions
  0.1.0 and Dart 3.12+/Flutter 3.44+ minimums. Inspector UI stays private. Coverage
  and Pana matrices now include applicable tooling packages; CI pins Flutter
  3.44.8 and checks actual plugin loading and browser builds.
- Repository formatting: **558 files, 0 changes** on the final check. Workspace
  fatal-info analysis and aggregate CI pass. Formatting the Dart 3.12 workspace
  normalized earlier milestone files; SDK analysis fixes preserve behavior.
- Browser compilation passes for the public Dart kit, catalog, save/upload,
  session replacement and inspector (release assets rebuilt). These are build
  contracts, not new interactive-browser or profile/release performance claims.
- Stress suites pass; benchmark harness: **60 tests passed**. Measurements are
  test-mode harness results, not the missing original-baseline comparison.
- Initial checkout dry-runs reported dirty/deleted tracked-file warnings. From
  an isolated snapshot without Git state, **all 10 publishable packages pass**
  using their coordinated local dependency graph. No publication occurred.
- At the M8 checkpoint, the **100% coverage gate was unchecked**: global coverage was **93.43%**,
  with eight runtime/tool packages below target. See [M8 validation](validation/0.1.0/M8.md) for final results,
  snapshot digest, limitations and evidence paths.

### Revised M7 validation recorded 2026-11-11

- Persistence transferred explicitly to [ecosystem roadmap](ecosystem_roadmap.md),
  preserving codecs/storage/migrations, task-cache/restoration work and acceptance
  criteria without keeping them as main 0.1.0 release gates. See the
  [revised plan](release_0.1.0_plan.md).
- Full `levit_dart` suite: **183 passed** (`m7-dart-full.log`), including 11 new
  elapsed-time/lifecycle regressions. Delayed ticks, sub-tick pause, deadlines,
  restart, callback reentrancy and combined cleanup failures are covered.
- Full Flutter bindings: **202 passed** (`m7-flutter-core-full.log`), including
  six new adapter tests for nullable/readable borrowing, mutable refreshes,
  duplicate listeners, reentrant disposal, family refresh and real widget unmount.
- Full Flutter kit: **17 passed** (`m7-flutter-kit-full.log`), including the runnable
  countdown/ValueListenable example and feature teardown. Public Dart kit: **2 passed**.
- Fatal-info analysis: clean across the workspace (`m7-workspace-analysis.log`) and
  individual changed packages/example. Corrected two earlier Flutter kit fixtures
  encountered during this validation (awaitable stop and an obsolete import).
- Scoped formatting check: **9 files, 0 changes** (`m7-format-check.log`).
- Countdown example release web build and Flutter Wasm compile dry-run: passed
  (`m7-example-web.log`). Example: `packages/kits/levit_flutter/example/lib/countdown_interop.dart`.
- API DartDoc, package READMEs/changelogs, architecture/LLM guidance and cumulative
  migration updated. No runtime storage dependency or persistence package added;
  `fake_async` is a test-only dependency for deterministic countdown regressions.
- Detailed acceptance evidence and milestone source manifest:
  [M7 validation](validation/0.1.0/M7.md). This does not certify the full release.

### M6 validation recorded 2026-11-11

- Full monitor suite: **171 passed**, including freeze/redaction, bounded queues,
  failure aggregation, socket/file cleanup and optional task-tree adapter coverage.
- Full reactive/scope suites: **537 / 231 passed**.
- Nexus app/server suites: **40 / 15 passed**, including two-client synchronization.
- Inspector CLI/relay: **4 passed**; private UI widget suite: **1 passed**.
- Fatal-info analysis: clean for monitor, reactive, scope, CLI, private UI and both Nexus packages.
- Release web build: passed with bundled CanvasKit/Roboto and local font fallback;
  Flutter’s Wasm compile dry-run also passed.
- Actual browser check: Nexus app and server sessions, ownership, live update details,
  filtering and recovery after relay restart. Port 9201 was used because another
  local service already occupied 9200; that service was left alone. Test processes stopped.
- CLI publication dry-run: **0 warnings, 4 hints** concerning local dependency
  overrides; no publication performed. Coordinated runtime versions remain an M8 gate.
- Melos discovers `levit_devtools` as publishable and `levit_devtools_ui` as private;
  existing CI/test/coverage discovery includes both.
- Source/asset manifest and detailed evidence: [M6 validation](validation/0.1.0/M6.md).
  This is milestone validation, not a clean release candidate or a 100% coverage claim.

### M5 validation recorded 2026-11-11

Durable logs are in `reports/validation/0.1.0/`:

- Full `levit_reactive` suite: **537 passed** (`m5-reactive-tests.log`).
- Full `levit_dart` suite: **172 passed** (`m5-dart-tests.log`).
- Full `levit_flutter_core` suite: **196 passed** (`m5-flutter-full.log`), including
  mounted family refresh, retained nullable status and obsolete result suppression.
- Catalog application regressions: **3 passed** (`m5-catalog.log`), covering
  pagination, optimistic rollback and repository closure after task cleanup.
- Fatal-info analysis: clean for those three runtime packages and the catalog
  (`m5-*-analysis.log`).
- Catalog release browser build: passed (`m5-catalog-web.log`), including Flutter's
  Wasm dry-run. Actual browser execution and release-wide coverage remain gates.
- Updated family/query/status DartDoc, four package READMEs, guidance and cumulative
  migration. Migrated stress-test status-builder callbacks to the new signatures.

### Validation recorded 2026-10-16

Using installed Dart 3.12.2 on 2026-10-16:

- In `packages/kits/levit_dart`, `dart --suppress-analytics test
  test/utilities/query_family_test.dart
  test/utilities/structured_task_contract_test.dart -r expanded`: **22 passed**.
- In `packages/core/levit_reactive`, `dart --suppress-analytics test
  test/family/lx_family_test.dart test/async/retained_status_test.dart
  -r expanded`: **10 passed**.
- This check fixed invalid const idle-state construction, nullable query fixture
  return inference, and the expected aggregate cleanup exception type.

Earlier runs recorded 535 reactive tests, 18 Nexus shared tests, 40 Nexus app tests,
and a real two-client WebSocket undo regression passing. Those results predate the
latest edits; the temporary logs are no longer available and are not certification
of the current checkout.

### Historical M8 blockers (superseded)

The following bullets describe the earlier M8 checkpoint. They are retained as
history; the final certification above resolves these gates, including 100%
coverage and the approved comparison-reference change.

- M5–M8 are complete. Remaining M1–M4 acceptance sign-off and release-wide gates
  still block candidate certification. Persistence remains outside the main release.
- All runtime/lint/inspector manifests now target 0.1.0 with Dart 3.12+ and Flutter
  3.44+ where applicable. Inspector UI remains private. All 10 publication dry-runs
  pass from an isolated source snapshot using local dependencies; nothing is published.
- M8 workspace formatting, fatal-info analysis, aggregate Dart/Flutter CI, browser
  build contracts, stress and benchmark tests pass. The unchanged 100% coverage
  gate is below target at **93.43%**. Profile/release diagnostics-on/off measurements and the
  original-baseline comparison remain open, as does final candidate certification.
- Changes remain uncommitted on top of the original unpublished work. M8 has an
  isolated source snapshot and durable manifest for validation, but it is not a
  certified prerelease candidate while the remaining gates are open.
- Recover original baseline evidence where possible and retain subsequent logs
  and candidate manifests in a durable location.
