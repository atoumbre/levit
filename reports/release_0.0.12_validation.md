# Levit 0.0.12 release validation

This candidate implements the lifecycle-correctness and API-cleanup release on
base commit `539f130`. Publication remains a separate, explicit action.

## Candidate identity

All eight publishable runtime packages and their internal version constraints
are coordinated at `0.0.12`. The lint package remains `publish_to: none`.

Publication validation uses a clean temporary Git snapshot, with local package
overrides resolving the candidate versions together. The original working tree
has not been committed or published. Runtime source files and package manifests
are compared by SHA-256 with the snapshot before completing validation.

Runtime manifest digest:
`2b1d3b66a2c9dd11ec058f86b85cbe0fdac4aae51016ca1f87df38b6e3c09c4e`.
The manifest maps each `packages/**/lib/**` file and package `pubspec.yaml` path
to its SHA-256; the digest hashes sorted compact JSON for that mapping.

## Acceptance evidence

| Contract | Behavioral evidence |
| :-- | :-- |
| Read-only reactive calls | Nullable concrete, `Object?`, and `dynamic` reads preserve values and emit no change; computed and Flutter-build reads are covered. Resolved-type migration distinguishes reactive writes from unrelated function calls. |
| Context-local batching | Both completion orders for concurrent batches; shared sources and outside writes; nested sync/async boundaries; observed diamond dependencies; callback/listener errors; escaped work; middleware/history completion and deduplication. |
| Registering-scope factory ownership | Multiple results and child resolution; reverse result/registration cleanup; permanent resets; replacement rejection; concurrent late creation and teardown; duplicate identities; initialization failures and aggregated disposal failures. |
| Awaited task shutdown | Queued, running, retrying and isolate tasks; late admission rejection; repeated disposal; public task errors; controlled uncooperative tasks; owned state and time/loop mixin resources survive until draining finishes. |
| Stores and views | Ancestor reuse and local isolation; shared async initialization; all four store-view factories; argument and scope updates; fresh resolver closures; scoped teardown. |
| Explicit bootstrap | Monitoring enabled/disabled crossed with linking enabled/disabled; executable Dart, Flutter, store, and monitor-filter fixtures; runnable example bootstrap and awaited teardown. |

Removed APIs have replacements in [the migration guide](../docs/MIGRATION_0.0.12.md).
The [audit disposition](feature_set_audit.md) records which broader proposals
remain excluded from this release.

## Checks

Completed on 2026-09-06. All release gates passed. Nothing was published.

| Gate | Result |
| :-- | :-- |
| Formatting | Passed across all packages; root stress script also formatted. |
| Analysis | Passed with fatal infos; root repository/script analysis also passed. |
| Dart tests | Passed in aggregate CI. |
| Flutter tests | Passed in aggregate CI, including documentation fixtures and examples. |
| Aggregate CI | Passed. |
| Coverage | Passed: 4,655 / 4,655 executable lines (100%) across all nine existing packages. |
| Stress | Passed with explicit successful test completion and no runner errors. |
| Benchmark harness | Passed. |
| Benchmark evidence | Regenerated successfully against this candidate. |
| Publication dry runs | Passed for all eight runtime packages from a clean candidate snapshot. |

The aggregate CI command runs the same analysis, Dart-test, and Flutter-test
commands configured by the individual Melos scripts. Coverage uses
`dart run scripts/check_coverage.dart --fail-under=100 --generate-report`.
Stress and benchmark evidence use `melos run stress`, `melos run benchmarks`,
and `melos run report:benchmarks`. Publication validation uses
`melos run publish:dry-run` inside the temporary snapshot.

Evidence: [coverage](packages_test_coverage.md),
[stress](stress_test_report.md), [benchmarks](bench_mark_report.md).
Benchmark timings use the repository's debug/test profile and are not
production performance guarantees.

## Failures investigated during verification

- Updated old tests that depended on unawaited removal or resolver identity
  causing a refetch. Their expectations now follow the deliberate release
  contracts.
- Changed the benchmark command to execute inside the benchmark package.
- Changed the stress runner to inspect test failure/completion events and allow
  Flutter reporter shutdown. It previously could report success after failed
  tests because it killed the runner on its completion event.
- Corrected stress fixtures: the flood now performs 100,000 actual value changes;
  the 100-layer diamond captures distinct observed nodes, uses representable
  numeric values, and asserts the exact result and one notification; lifecycle
  workloads await cleanup. No workload counts or coverage thresholds were reduced.
- Bulk teardown exposed a full-map scan per removed registration. Cleanup now
  removes its retiring entry directly by key; the 500,000-registration stress
  workload completes.
- Publication dry runs in the modified checkout raised dirty-tree warnings.
  The clean temporary candidate snapshot resolves that validation condition.

## Operational contracts

Factory resources remain owned until their registering scope removes them.
Async batching coordinates notifications while values remain shared. Tasks
that ignore cancellation can delay disposal indefinitely; caller timeouts do
not complete cleanup. Tasks must release local resources in their own completion
paths and must not await disposal of their own owner.
