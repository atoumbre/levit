# Levit 0.1.0 candidate recertification

**Recertified on 2026-11-11; not published.** All eight revised milestones and
release gates are complete. The optimized source passes functional, packaging,
coverage and corrected performance checks. Remaining baseline performance costs
are explicitly recorded; this is not a claim of performance parity.

The previous performance certification is superseded. The legacy monitor stayed
registered after `close()`, contaminating mixed diagnostics rounds. Its reported
notification/fan-out speedups are withdrawn. Historical evidence and the original
source archive remain preserved. The new comparison explicitly detaches middleware
and measures each diagnostics state in a separate process.

## Candidate identity

- **877 source files**, **23 exact dependency lockfiles**: 22 workspace
  packages plus the private root tool package. All ten publishable packages are
  **0.1.0**. Inspector UI remains private; persistence remains on the separate
  ecosystem roadmap under the approved M7 revision.
- [Source archive](../../../build/release_0.1.0/9ea48ef041759b5e/levit-0.1.0-source.tar.gz): **15,376,768 bytes**, in the ignored build directory.
- [Source manifest](candidate-source.sha256), SHA-256:
  `9ea48ef041759b5ed428dd8075415d914ff715a9d33dcaf02799160f2982660f`.
- Archive SHA-256: `71bde2babb481459a689590c0aa0cd4b1e693bcaa75c0e0cf0a8445e6521b880`.
- [Dependency manifest](candidate-dependencies.sha256), SHA-256:
  `c532e4fc9cf2bcafde7976cfc989baa31d7de50dbe3962d87598e23896ccd6e5`.
- [Machine-readable certificate](candidate-certification.json),
  [gate results](candidate-gates.json), [local package graph](candidate-package-graph.json).

Every archived source and lockfile was read back and checked against the embedded
`SOURCE.sha256` and `DEPENDENCY_LOCKS.sha256`. All 23 dependency locks match the
original candidate. All runtime/build inputs in the working checkout match the
validated isolated candidate. Only the final progress report was synchronized
after validation. The archive includes bundled inspector assets; it excludes Git
metadata, ignored build output, deleted files, symlinks and validation evidence.
Evidence is retained beside this certificate and separately checksummed.

This source replaces manifest
`4c6b6f64dfac2f0bbd8f32dfe30519e51bfd4ec51652ddc7543334eb3f9da1bf`.
The old archive is retained for the before/after comparison. No Git commit, tag,
publication or user global installation was performed; the existing uncommitted
work remains intact.

## Validation

Toolchain: **Dart 3.12.2 / Flutter 3.44.8**, macOS 26.6.2, Apple M1 Pro.

| Gate | Result | Evidence |
| --- | --- | --- |
| Coordinated dependencies | All 22 packages plus root resolve together; local package roots remain inside the isolated candidate after CLI activation; exact locks unchanged | [Dependency checks](recertification/dependencies.log), [final graph/migration check](recertification/final/dependencies-and-migration.log) |
| Formatting | 582 Dart files, zero changes | [Format](candidate-snapshot-format.log) |
| Fatal-info analysis | Root and aggregate package analysis pass | [Root analysis](candidate-root-analysis.log), [CI](candidate-ci.log) |
| Native lint plugin, Dart and Flutter suites | All pass, including real consumer plugin loading, ownership/task failure paths and Nexus two-client convergence | [CI](candidate-ci.log) |
| Existing 100% coverage gate | **6,524 / 6,524 executable lines across 11 packages**; threshold and exclusions unchanged | [Coverage](candidate-coverage.log) |
| Browser compilation | Public Dart kit, catalog, save/upload, session replacement and inspector all pass | [Five browser builds](candidate-browser-builds.log) |
| Reproducible inspector | All 35 release assets match between working and isolated builds; nondeterministic `.last_build_id` excluded | [Asset verification](candidate-assets.log), [rebuild](candidate-inspector-rebuild.log) |
| Stress | Runtime and Flutter suites pass | [Stress](candidate-stress.log) |
| Benchmark harness | All 67 tests pass, including cleanup/frame matching and monitor detachment | [Benchmarks](candidate-benchmarks.log) |
| Optimization regressions | Five monitor tests and 26 task/group/shutdown tests pass; reference teardown regression also passes | [Monitor](recertification/monitor-regressions.log), [tasks](recertification/task-regressions.log), [reference teardown](recertification/corrected-before/reference-detach-test.log) |
| Native comparison | All 24 separate processes pass: three revisions × profile/release × diagnostics off/on × two orders; 12,960 timed samples, 4,320 matched frames | [Run log](recertification/final/performance-runs.log), [corrected report](PERFORMANCE.md) |
| Publication preparation | All ten publishable packages pass dry-run; final inspector file-list dry-run passes | [Dry-runs](candidate-publish-dry-run.log), [inspector package](candidate-cli-final-dry-run.log) |
| Installed inspector | Isolated-cache activation; HTML, JavaScript and bundled font manifest served with only Dart on PATH; awaited interrupt shutdown exits 0 | [Consumer checks](candidate-cli-consumer.json), [activation](candidate-cli-activation.log), [result](candidate-cli-global-check.log) |
| Migration and boundaries | Removed API scan passes; negative API and readable contracts pass in CI/coverage; private UI and optional ecosystem boundary retained | [Migration checks](candidate-migration-checks.json), [M1–M4 sign-off](SIGNOFF_M1_M4.md) |

Commands include `dart format --output=none --set-exit-if-changed .`,
`dart analyze --fatal-infos`, `dart run scripts/ci.dart`,
`dart run scripts/check_coverage.dart --fail-under=100 --timeout=600 --generate-report`,
`dart run scripts/stress_test.dart`, `dart run melos run benchmarks --no-select`,
`dart run scripts/publish_dry_run.dart`, and the six native builds / 24 runs in
[the benchmark workflow](../../../benchmarks/README.md).

The browser build script ran from the working checkout with the same runtime and
build source subsequently verified against the isolated candidate. The inspector
was also rebuilt inside the candidate and compared byte for byte. Other final
functional, coverage and packaging gates ran inside the isolated candidate. No
builds/tests ran concurrently with final native measurement.

## Fixes in the recertified source

- Explicit legacy monitor detachment with registry assertions; diagnostics off/on
  isolated by process. Identical screen placement, display checks, activity guard
  and frame-ID matching apply to all three revisions.
- Constant-time task pending accounting, optional diagnostic event allocation and
  removal of a redundant execution zone. Typed outcomes, group supervision,
  cancellation/deadline semantics and self-disposal guards remain tested.
- Direct deep freezing of ordinary JSON envelopes, retaining custom JSON conversion
  and unsupported/cyclic value rejection. Redaction and immutable capture still
  occur before buffering; wire format is unchanged.
- Synchronous transport sends avoid artificial future boundaries; asynchronous
  sends remain ordered and awaited through flush/close.
- Scope progress uses already-JSON, value-free metadata without repeated generic
  normalization; no-observer progress dispatch returns immediately. Genuine
  two-phase cleanup and its error/drain semantics remain unchanged.

The full suites and added regression tests exercise these changes. The improved
results below measure their combined effect; they are not individual CPU-profile
attributions to each optimization.

## Corrected performance and approved baseline

The user approved **539f130da148d1a802925d02363996f82ae4a323** because the original
unpublished 0.0.12 archive is unavailable. That baseline substitution remains
explicit and excludes unpublished changes. All 74 reference runtime inputs match
Git; all 128 original-candidate package library files remain unchanged; all three
builds share 44 external dependency versions and the corrected measurement host.

Compared with the original candidate, release leaf-task latency falls **46.7%**;
monitored notification/fan-out/scope latency falls **31.9% / 31.1% / 36.3%**.
Remaining baseline costs are material: leaf tasks **+63.0%** (2.56 vs 1.57 µs/task),
scope lifetimes **+49.4%** (3.57 vs 2.39 µs/scope), and monitored workloads
**1.8–3.8×** the reference. Structured cleanup, task guarantees, immutable/redacted
monitoring and extra ownership events are retained. Code-informed explanations
and complete before/after tables are in [the performance report](PERFORMANCE.md).

Unmonitored notification aggregates are +11.7% in release / +36.3% in profile,
but round ranges overlap widely, including between candidates with identical
reactive source. Fan-out is +2.0% release / −1.1% profile. These small/variable
workloads do not establish a stable speedup or regression. UI wall time remains
near 8.33 ms display pacing; separate build/raster timings are retained. No
zero-regression performance budget was specified, and the certificate makes no
blanket speedup claim.

## Limits and publication boundary

- One native macOS host; background desktop applications remain present. Browser
  checks establish compilation, not interactive browser/mobile performance.
- Diagnostic counting transport includes JSON/UTF-8 serialization and a 10,000-event
  history; it excludes network/disk IO and the optional task bridge. RSS observations
  are not evidence of retained memory or absence of leaks. History/statistics
  remain disabled by default.
- Coverage is executable line coverage, not branch coverage or a proof of general
  cancellation correctness. Focused failure-path acceptance remains documented.
- Dry-runs use coordinated local overrides because 0.1.0 is not yet published.
  Expected override hints remain; hosted resolution and server-side publication
  checks belong to the separate publication action.
- The archive is a local unsigned candidate artifact. Publication and release
  tagging require a separate instruction. **Nothing has been published.**

[Progress report](../../release_0.1.0_progress.md) ·
[Cumulative migration guide](../../../MIGRATION_0.1.0.md) ·
[Ecosystem roadmap](../../ecosystem_roadmap.md)
