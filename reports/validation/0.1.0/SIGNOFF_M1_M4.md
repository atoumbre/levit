# M1–M4 acceptance and coverage sign-off

Generated run artifacts were removed during cleanup on 2026-11-24. Historical artifact paths refer to Git commit `bd1a095`.


Validation date: 2026-11-11. Toolchain: Dart 3.12.2 / Flutter 3.44.8.
M1–M4 are complete: implementation, migration/documentation review, permanent
acceptance regressions and full integration validation pass. This signs off the
milestones; the remaining release-wide candidate/performance gates stay separate.

## Acceptance matrix

Paths below are relative to the repository root. Every listed test is included
in aggregate CI; runtime/tool tests are also included in the coverage gate.

| Milestone | Acceptance | Permanent regression evidence |
| --- | --- | --- |
| M1 | Pending singleton/factory initialization, late results, owned/borrowed children, explicit factory permanence, repeated cleanup and dependency release order | `packages/core/levit_scope/test/core/awaited_lifetime_contract_test.dart`, `factory_ownership_contract_test.dart` |
| M1 | Aggregate cancellation/drain/close errors, initialization adopted during draining, failing children and immutable progress notifications | `packages/core/levit_scope/test/core/cleanup_failure_acceptance_test.dart` |
| M1 | Initializers reject self/ancestor disposal; concurrent early releases drain independently; scope close waits for releases and reports their failures | `packages/core/levit_scope/test/core/initialization_boundary_test.dart` |
| M1 | Controllers/stores capture async initialization; explicit ownership adapters; async disposal callbacks; expired contexts; delete/reset/early release reject self-disposal before mutation | `packages/core/levit_dart_core/test/controller/cleanup_acceptance_test.dart`, `initialization_boundary_test.dart`, `async_owner_contract_test.dart` |
| M1 | Workers, superseded executions, async computed/future wrappers and stream cancellation finish before dependencies close; middleware errors cannot skip cleanup | `packages/core/levit_reactive/test/core/async_lifetime_contract_test.dart`, `cleanup_failure_acceptance_test.dart` |
| M1 | Loops await the current iteration; manual pause survives lifecycle changes; retries and isolates drain before owner resources | `packages/kits/levit_dart/test/utilities/loop_lifetime_contract_test.dart`, `task_shutdown_contract_test.dart`; Flutter lifecycle mixin tests |
| M1 | Rapid widget replacement coalesces; obsolete initialization failures stay in their generation; cleanup failure/retry and unmount during initialization are awaitable | `packages/core/levit_flutter_core/test/widgets/scope_replacement_contract_test.dart`, `lifecycle_acceptance_test.dart`; `examples/scope_playground/test/` |
| M2 | Definition identity with shared tags and widened result types; ancestor reuse; isolated sync/async overrides owned by the receiving scope; local-only lookup | `packages/core/levit_dart_core/test/store/store_identity_override_test.dart`, `local_store_contract_test.dart`; `packages/core/levit_flutter_core/test/view/local_store_contract_test.dart` |
| M2 | Missing optional registrations return absence while construction/type errors propagate; scope descriptions are immutable and omit values/raw tags | `packages/core/levit_scope/test/core/observation_contract_test.dart`, `cleanup_failure_acceptance_test.dart` |
| M2 | Readable interfaces reject mutation, refresh, metadata setters and disposal at compile time; normal reads and typed recipes compile | `packages/core/levit_dart_core/test/core/public_surface_contract_test.dart`; nullable read and Flutter builder/selector tests |
| M2 | Isolated test scopes install overrides, await real work/cleanup, and report both work and teardown failures | `packages/core/levit_dart_core/test/store/store_identity_override_test.dart`, `test/controller/cleanup_acceptance_test.dart`; scope-playground widget override tests |
| M3 | Removed APIs fail analysis; explicit registration and replacement APIs compile; repository consumers use the shipped surface | `packages/core/levit_dart_core/test/core/public_surface_contract_test.dart`, aggregate fatal-info analysis, migrated scope registration tests |
| M3 | Creation undo restores collections; redo reconstructs values; immutable bulk/drag commands publish atomically; previews produce one entry; new edits clear redo; history is bounded to 100 | `examples/nexus_studio/shared/test/command_history_test.dart` |
| M3 | Presence preserves history; authoritative snapshots/remote document edits clear it; node deletion is idempotent; inverse creation/movement converge across two real WebSocket clients | `examples/nexus_studio/shared/test/command_history_test.dart`, `examples/nexus_studio/server/test/two_client_undo_test.dart` |
| M4 | Single-slot nested coordination, both failure policies, cancellation trees, unrelated root work, body/descendant/finally completion and isolate cancellation | `packages/kits/levit_dart/test/utilities/structured_task_contract_test.dart`, `task_group_acceptance_test.dart`, `task_shutdown_contract_test.dart`; `examples/task_board/test/` |
| M4 | Earliest inherited deadlines include queue time; expired tasks never start; bounded queues preserve joins/coalescing; weighted priorities avoid starvation while preserving FIFO | `packages/kits/levit_dart/test/utilities/structured_task_contract_test.dart`, existing engine conflict-policy tests |
| M4 | Successful null differs from cancellation/drop/supersession; explicit classifiers and capped jittered retries; cancellation is never retried; reactive task-tree metadata and cleanup failures | `packages/kits/levit_dart/test/utilities/structured_task_contract_test.dart`, `task_group_acceptance_test.dart`, `query_cleanup_acceptance_test.dart` |

## Fixes found during sign-off

- Scope cleanup now collects initialization failures only after all adopted work
  has drained. Earlier cleanup could report success before a late failure arrived.
- External/widget setup uses `runInitialization` to admit work before invoking
  user code. Async DI and captured controller/store initialization keep execution
  guards until completion. Self-disposal is rejected before removal or closing
  state changes, including delete/reset and early factory release.
- Early factory release follows cancellation → drain → close, stays tracked by
  the scope, and preserves the releasing owner's execution boundary. Concurrent
  releases do not wait on one another. Release errors remain observable through
  both the release future and subsequent registration/scope disposal.
- Flutter replacement handles reentrant requests and listener-triggered close;
  its completion future cannot resolve before the cleanup pump finishes.
- Reactive middleware failure no longer skips resource release. Async source
  cleanup aggregates producer and observation errors after both complete.
- Task/query shutdown retains admitted runners/refreshes until their bookkeeping
  and cleanup settle. Removed duplicate unreachable guards without weakening the
  public admission checks.
- WebSocket monitoring explicitly owns subscription cancellation, retaining its
  failures in awaited shutdown. Inspector capacity rejection uses a supported
  close code; HTTP failures finish cleanup and retain the original error; stale
  handshakes cannot disconnect replacement connections; ancestry cycles render.

Regression-first logs retain the reproduced failures for initialization guards,
early-release error propagation and release execution boundaries. The corrected
focused runs are in `signoff-scope-init-regressions.log` and
`signoff-owner-init-regressions.log`.

## Documentation and migration review

The cumulative `MIGRATION_0.1.0.md`, ownership/observation/task DartDoc and package
READMEs describe awaited two-phase cleanup, explicit adapters, typed stores,
readable views, factory release, initialization guards and structured tasks.
The scope README's obsolete implicit-permanence statement and Dart kit's
future-tense task-group guidance were corrected. Existing tests with removed
API names in their labels now describe explicit registration/ownership.

Removed public APIs are retained only as migration/history references or negative
test fixtures. `LWidgetMonitor` is replaced by the local mount/unmount recipe.
The native lint plugin, onboarding and examples keep their existing M8 coverage.
Persistence remains on the independent ecosystem roadmap under the approved M7
revision; no persistence package or runtime storage dependency was added.

## Validation results

| Check | Result | Evidence |
| --- | --- | --- |
| Unchanged aggregate 100% coverage gate | **6,508/6,508 executable lines**, all 11 packages, exit 0 | `signoff-aggregate-coverage.log`, [coverage table](../../packages_test_coverage.md) |
| Repository formatting | 568 Dart files across 22 packages, 0 changes | `signoff-format.log` |
| Native plugin, fatal-info analysis, all Dart/Flutter tests | Pass, including Nexus command history and two-client WebSocket convergence | `signoff-ci.log` |
| Removed API implementation/consumer scan | No removed API references in non-test Dart source | `signoff-removed-api-scan.log` |
| Runtime and Flutter stress suites | Pass | `signoff-stress.log`, `reports/stress_test_report.md` |
| Browser contracts: public Dart kit, catalog, save/upload, session replacement, inspector | All five pass; bundled inspector release assets rebuilt | `signoff-browser-builds.log` |
| Benchmark harness | All 60 tests pass | `signoff-benchmarks.log` |

Commands: `dart run scripts/check_coverage.dart --fail-under=100 --timeout=600`,
`dart run melos run format --no-select`, `dart run scripts/ci.dart` and
`dart run scripts/stress_test.dart`, `dart run scripts/check_browser_builds.dart`
and `dart run melos run benchmarks --no-select`. The coverage script, threshold and existing
exclusions were not changed for this follow-up. Tests assert public behavior and
failure/cleanup ordering; no new coverage-ignore directives were added.

## Validated source record

`signoff-source.sha256` records **868** existing tracked and non-ignored untracked
source files after the final browser assets were rebuilt. Deleted files, symlinks
and `reports/validation/` output are excluded. The original dirty working tree was
preserved; no commit or publication was performed.

Manifest SHA-256:
`85df53104e1944140438183e03eb474d403b14db01762bebd80e176825e5d7ea`.

This identifies the validated working-tree source, not a clean publication
candidate or the unavailable original unpublished baseline. The earlier M8
isolated-snapshot dry-runs remain historical; final candidate validation must
use the completed release source and coordinated local dependency graph.

## Boundaries of this sign-off

The coverage gate measures executable line coverage, not branch coverage or a
proof of general cancellation safety. Cancellation remains cooperative; a
deadline never substitutes for completed cleanup. `trackInitialization` adopts
an already-started future; only `runInitialization` can establish a new guarded
execution context for external setup.

Browser build checks are compilation contracts, not interactive performance
measurements. Stress/benchmark harness tests do not replace the still-open
profile/release diagnostics-on/off comparison against the original unpublished
baseline. That original temporary archive is unavailable. Final candidate
certification and publication remain separate from M1–M4 acceptance.

## Performance-remediation follow-up, 2026-11-11

The user subsequently approved committed `539f130` as the comparison reference,
explicitly excluding the missing unpublished changes. Current timings and source
certification are recorded in [PERFORMANCE.md](PERFORMANCE.md) and
[CANDIDATE.md](CANDIDATE.md); the source identity above remains historical.

The performance work retains cancellation/draining, initialization execution
guards, stable disposal futures, LIFO cleanup and aggregate errors. It also adds
permanent coverage for two newly observed failure paths:

- `task_hot_path_contract_test.dart`: a task cannot await its own scope while
  its registration is already retiring. The guard regression failed before the
  fix and passes afterwards.
- `cleanup_failure_acceptance_test.dart`: failing deletion/disposal middleware
  cannot skip later observers or resource cleanup. Synchronous and asynchronous
  release aggregate every failure; delete/reset behave consistently, and alias
  deletion preserves canonical ownership.

Task regressions also cover late cancellation/outcome observation, successful
nullable results, asynchronous admission and distinct root/child task identities.
Scope lookup tests retain alias invalidation, ancestor reuse and isolation after
making optional bookkeeping lazy. The frozen-candidate validation logs in
`performance-remediation/` record the complete suites and unchanged coverage gate.
