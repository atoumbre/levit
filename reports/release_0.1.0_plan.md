# Levit 0.1.0 — Ownership, Refresh, and Developer Tooling

M5 is revised by the [family replacement specification](reactive_collections_redesign_2026-11-13.md): precise collection entries, LxResource in reactive core, and LevitAsyncMap in the Dart kit supersede the family deliverables below.

## Objective and approved scope

A feature can load data, refresh it, run child tasks, interoperate with Flutter,
and close reliably, with inspectable ownership and tested examples.

This records the implementation plan with the approved M7 scope revision.
The [feature audit](feature_usefulness_audit_2026-09-15.md) supplies the original
findings; [progress](release_0.1.0_progress.md) records implementation and evidence.

- Build on the unpublished 0.0.12 work, preserving that baseline.
- Target 0.1.0 and Dart 3.12+ / Flutter 3.44+; validate with 3.12.2 / 3.44.8.
- Remove obsolete APIs immediately; provide migration documentation without aliases.
- Keep stores, aliases, independent resource owners, consuming/owning views,
  async wrappers and isolates. Keep selection/time conveniences, LKeepAlive,
  staticDeps and batchAsync in advanced guidance.
- Persistence is explicitly transferred to the [ecosystem roadmap](ecosystem_roadmap.md).
  Storage interfaces, codecs, migrations, file/SharedPreferences storage, persistent
  task caches and codec-based restoration are outside this release's requirements.
- All eight **revised** milestones remain required. Publication is a separate action.

## Ordered milestones

### M1 — Reliable disposal and scope replacement

Close admission/notification immediately, then await tracked work and cleanup.
Owners request cancellation/drain before releasing remaining resources in reverse
ownership order; disposal failures aggregate after all attempts. Support explicit
`own` disposers, async `LevitRef.onDispose`, owned child scopes with a borrowed
option, awaited factory release, and self-deadlock rejection.

Drain workers, wrappers, stream cancellation, loops, singleton initialization and
factories. Preserve manual pause intent. Serialize/coalesce Flutter scope replacement
by captured generation, expose loading/cleanup failure/retry, and provide awaitable
replacement/unmount completion through the lifecycle controller.

### M2 — Store identity and observation/testing APIs

Identify stores by definition identity plus variant. Add typed context/ref lookups
and scope-local builder overrides, preserving explicit ancestor inheritance.
Optional lookup hides only absence. Expose observation through `LxReadable<T>`,
immutable value-free scope descriptions and isolated testing/cleanup entrypoints.

### M3 — Remove obsolete surfaces and migrate Nexus commands

Remove `.toBuilder`, `.levitPut`, `.levitLazyPut`, `.levitLazyPutAsync`, `autoDispose`,
`initialized`, `computedValue`, `cancelOnClose:`, void graceful `stop`, reactive
history middleware, `LWidgetMonitor` and dynamic store-key lookup. Migrate consumers
in the same milestone. Replacements remain those in `MIGRATION_0.1.0.md`.

Nexus uses immutable domain commands keyed by node ID for creation, movement,
color and bulk movement. Batch execute/undo/redo atomically; one drag creates one
entry, previews none. Bound history to 100; new edits clear redo, remote document
changes clear history, presence does not. Synchronize inverse operations, including
idempotent `node_delete`, and test two-client convergence.

### M4 — Structured tasks and bounded scheduling

Add controller-root/child task groups, supervisor and cancelOnError policies,
inherited deadlines, typed cancellation/skipping exceptions and execution outcomes.
Groups drain all descendants/finally blocks; only leaves consume slots. Bound pending
submissions to 256 by default with explicit unbounded opt-in, retain six conflict
policies, and use FIFO within priority with weighted fairness across priorities.
Retries require classification and capped exponential backoff/jitter; cancellation
and deadlines are never retried. Preserve isolate entrypoints/cancellation and
expose task-tree metadata with counts and cancellation reasons.

### M5 — Precise collections and replaceable producers

Implement per-address observation in LxMap and LxList, a standalone owned
LxResource in reactive core, and LevitAsyncMap in the Dart kit. Collections
borrow contents. The async map owns keyed producers, drains them on replacement
and eviction, and preserves mounted entries across refresh. Follow the
[seven stages](reactive_collections_redesign_2026-11-13.md), migrate existing
consumers and recertify against both frozen comparison references.

### M6 — Awaited monitoring and local inspector

Await attach/replacement/flush/detach. Disable history/statistics by default; freeze
redacted immutable envelopes before buffering. Bound history/queues, count drops,
and distinguish recovered snapshots from complete history. Keep protocol/models
browser compatible and file transport behind an IO entrypoint. Include lifecycle
progress and an optional application task bridge.

Provide publishable `levit_devtools` with a Dart CLI, bundled private Flutter web
UI and read-only WebSocket relay. Default to loopback port 9200 and producer `/ws`.
Support sessions, ownership/reactions, update details, task trees, unfinished cleanup,
filtering, bounded timeline and redacted JSON export. Validate Nexus app/server
sessions, recovery and packaged startup without hosted infrastructure.

### M7 — Native Flutter interoperability and elapsed countdowns (revised)

- Add `LxValueListenable<T>` / `LxReadable.asValueListenable()` in existing Flutter
  bindings, re-exported through `levit_flutter`.
- Borrow the source: creation does not subscribe, the first listener subscribes,
  the last removal unsubscribes, and disposal never closes or mutates the source.
- Preserve null values, source refreshes and Flutter listener behavior. Stable resource
  handles continue notifying across refresh. Dispose adapters at their owning widget
  or controller boundary, and test actual ValueListenableBuilder consumption.
- Calculate `LxCountdown` from monotonic elapsed time. Delayed callbacks catch up
  without replaying missed ticks; clamp at zero and finish once per completed run.
- Pause freezes precise remaining time, including partial intervals; resume excludes
  paused time. App lifecycle changes do not automatically pause a countdown.
- Define start as a fresh run, stop as reset without completion, and zero duration
  as asynchronous completion. Reject negative durations/non-positive intervals.
- Cancel timing immediately on disposal and await reactive cleanup. Preserve task
  draining order and test delayed cleanup and callback reentrancy.
- Add DartDoc, package READMEs, migration guidance and a runnable example.

**Acceptance:** adapter disposal leaves its source usable; widget unmount releases
subscriptions; delayed timer delivery produces elapsed-time-correct results;
pause/resume, restart, zero, repeated cleanup and owner teardown are covered.
No persistence package or persistence abstraction is introduced in the main repo.

### M8 — Safety tooling and onboarding

Ship publishable native analyzer-plugin lint configuration and focused rules for lifecycle
delegation, scoped resolution and discarded known lifecycle/worker futures. Test
valid patterns alongside violations; do not claim general cancellation analysis.
Finish runnable pagination/task-group/scope-replacement/override examples, onboarding
(scopes → owners → state → widgets), architecture guidance, advanced documentation,
and cumulative migration. Keep recommended imports `levit` / `levit_flutter`.
Coordinate runtime/lint/inspector versions and SDK minimums; keep the inspector UI
private. Ecosystem packages have independent versions and release schedules.

Validation entry points: `scripts/check_lint_plugin.dart` exercises a real consumer;
`check_browser_builds.dart` compiles the Dart kit, query/workflow/session examples
and bundled inspector. CI discovers all packages; coverage includes the three
tooling packages and keeps its 100% threshold. Publication remains separate.

## Acceptance and release gates

| Area | Required acceptance |
| --- | --- |
| Lifetimes | Initialization, workers, loops, retries, streams and isolates drain before dependencies; cleanup idempotence/error aggregation. |
| Flutter | Rapid replacement, obsolete failure, cleanup failure/retry and unmount during initialization. |
| Stores | Distinct definitions sharing tags, inheritance, local/async overrides and construction-error propagation. |
| Families | Builder/computed/worker continuity, refresh failure, nullable retention, eviction and stale completion. |
| Tasks | Single-slot nested groups, both failure policies, cancellation trees, deadlines, saturation, fairness, retries and successful null. |
| Nexus | Atomic drag undo, collection restoration, redo clearing, remote resets and two-client convergence. |
| Diagnostics | Redaction through live/reconnect/export, bounded retention/drop accounting, awaited shutdown and packaged CLI. |
| Revised M7 | Borrowed-source ownership, listener/widget lifecycle, delayed ticks, precise pause, restart and awaited countdown cleanup. |

Persistence restart/migration/corruption/IO acceptance lives in the ecosystem
roadmap and is no longer a main 0.1.0 release gate.

Run formatting, fatal-info analysis, Dart/Flutter tests, aggregate CI, the existing
100% coverage gate, stress tests, benchmarks and publication dry-runs. Discovery
includes every main-repository package and the inspector UI. Build supported browser
runtimes/inspector; record profile/release performance with diagnostics off/on against
the approved comparison reference below. Missing baseline evidence must remain visible.

**Approved comparison revision (2026-11-11):** the original unpublished 0.0.12
archive is unavailable. The user approved committed revision `539f130` as the
performance reference. Record its full identity and keep the exclusion of the
unpublished changes explicit; do not present it as the recovered original archive.

Validate a clean candidate with local dependencies resolved together, record its
source digest, results, limitations and migration checks. Completion means a
validated, documented, publish-ready candidate; milestone checkboxes alone do not
certify release readiness.

Exclude a router, ORM, HTTP/forms framework, durable workflow scheduler and
collaborative undo engine. The moved persistence scope remains tracked separately,
not silently marked complete or required to ship alongside 0.1.0.
