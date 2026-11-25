# Levit 0.1.0 candidate certification

**Validated and recertified on 2026-11-11; not published.** All eight revised
milestones and release gates pass. Reopened performance work addressed the
profiled hot paths and two newly discovered cleanup failures. Small residual
costs and UI variability are explicitly retained; this is not a performance-parity
claim for every workload or platform.

## Candidate identity

- **882 source files**, **23 exact dependency locks**: 22 workspace
  packages plus the private root tool package. All ten publishable packages are
  **0.1.0**. Inspector UI remains private; persistence remains ecosystem-only.
- [Source archive](../../../build/release_0.1.0/183b91fa9bf88736/levit-0.1.0-source.tar.gz):
  **15,388,102 bytes** in the ignored build directory.
- [Source manifest](candidate-source.sha256), SHA-256:
  `183b91fa9bf8873659ebe50c8caf2d435a50887e837c1dd82402c9fb57f07c8f`.
- Archive SHA-256: `f8011fbf39b7978bddf3e999efd8ee4cc0a5b6fff41886ed57cbc88eae8a8a21`.
- [Dependency manifest](candidate-dependencies.sha256), SHA-256:
  `c532e4fc9cf2bcafde7976cfc989baa31d7de50dbe3962d87598e23896ccd6e5`.
- [Machine certificate](candidate-certification.json),
  [gate results](candidate-gates.json), [local package graph](candidate-package-graph.json).

Every archived source and dependency-lock byte was read back and verified against
the embedded manifests. All 23 locks match the initial candidate. Runtime/build
inputs match the isolated snapshot used for validation; final report text was
synchronized after validation. The archive includes reproducible bundled inspector
assets and excludes Git metadata, ignored build products, deleted files, symlinks
and validation evidence. [Evidence hashes](candidate-evidence.sha256) identify the
separately retained logs, profiles and raw timings.

This supersedes source manifest
`9ea48ef041759b5ed428dd8075415d914ff715a9d33dcaf02799160f2982660f`.
The previous source archives and certificates are preserved in
`build/release_0.1.0/` and
[performance-signoff-reopened](performance-signoff-reopened/CANDIDATE.md).
No publication, Git commit, tag or user global installation was performed.

## Validation

Dart **3.12.2**, Flutter **3.44.8**, macOS 26.6.2, Apple M1 Pro.
All functional/build gates run in the isolated snapshot with coordinated local
dependencies. Native comparisons use matching working runtime/build inputs;
source hashes and executable/AOT hashes are retained.

| Gate | Result | Evidence |
| --- | --- | --- |
| Coordinated dependencies and migration | 23 packages including root; 112 local package roots verified after isolated CLI activation; all ten versions 0.1.0; 23 locks unchanged; negative API/readable and Nexus convergence tests pass | [Dependency/migration verification](performance-remediation/dependencies-and-migration.json), [CI](performance-remediation/snapshot-ci.log) |
| Formatting | 587 Dart files, zero changes | [Format](performance-remediation/snapshot-format.log) |
| Native lints, fatal-info analysis, Dart and Flutter tests | Complete aggregate CI passes | [CI](performance-remediation/snapshot-ci.log) |
| Existing 100% coverage gate | **6,747 / 6,747 lines across 11 packages**; threshold/exclusions unchanged | [Coverage](performance-remediation/snapshot-coverage.log) |
| Stress | Runtime and Flutter suites pass; final generated report refreshed from the snapshot | [Stress](performance-remediation/snapshot-stress.log), [report regeneration](performance-remediation/final-stress-report.log) |
| Benchmark harness | All 67 tests pass | [Benchmarks](performance-remediation/snapshot-benchmarks.log) |
| Browser builds | Public Dart kit, catalog, save/upload, session replacement and inspector pass | [Five targets](performance-remediation/snapshot-browser-builds.log) |
| Reproducible inspector | All 35 bundled assets match independent working/snapshot builds; `.last_build_id` excluded | [Asset hashes](performance-remediation/inspector-assets.json), [independent rebuild](performance-remediation/root-inspector-rebuild.log) |
| Publication preparation | All ten publishable packages pass dry-run | [Dry-runs](performance-remediation/snapshot-publish-dry-runs.log) |
| Packaged inspector | Isolated-cache activation; HTML, JavaScript and font manifest served with only Dart on PATH; awaited interrupt shutdown exits 0 | [Consumer results](performance-remediation/candidate-cli-consumer.json), [activation](performance-remediation/candidate-cli-activation.log) |
| Profiled runtime changes | Tasks, scopes, monitored updates and isolated UI profiled; permanent regressions and complete suites pass | [Performance report](PERFORMANCE.md), [M1–M4 follow-up](SIGNOFF_M1_M4.md) |
| Native comparison and replication | **32 isolated processes, 17,280 samples, 5,760 matched frames**; two complete matrices use identical executables/AOT, separate diagnostics states and reversed orders | [All runs](performance-remediation/replicated-comparison/run.log), [binary verification](performance-remediation/repeat-status.json), [raw-run manifest](performance-remediation/replicated-comparison/run-files.json) |

The [validation state record](performance-remediation/validation-status.json)
contains exact commands, locations, start/end times and exit codes. No builds,
tests, profiling or compression overlapped either final timing matrix. Additional
UI profiling runs sequentially after timing; its fixture and raw responses are
retained separately and do not alter the candidate source.

## Changes and preserved guarantees

- Monitor capture reuses timestamps and immutable field layouts, avoids repeated
  copies and expands compact ownership records lazily. Redaction, custom JSON,
  complete progress/reconnect state, bounded retention and awaited delivery remain.
- Task outcomes/cancellation futures are observed lazily; no-cache paths avoid
  redundant continuations; actual runners remain tracked. Async admission,
  nullable success, cancellation reasons, group identity and draining remain.
- Scope bookkeeping, aliases and ancestor caches allocate on demand. Cleanup
  avoids unnecessary futures/collections while retaining initialization guards,
  stable completion futures, LIFO release and error aggregation.
- Closing registrations retain self-disposal guards while work drains. Failing
  deletion/disposal middleware cannot skip later observers/resource cleanup or
  mask earlier errors. Delete/reset and non-owning aliases have permanent tests.

Public contracts and wire changes are documented in package READMEs, DartDoc and
[MIGRATION_0.1.0.md](../../../MIGRATION_0.1.0.md). The versioned compact progress
record is self-contained; the matching inspector decoder is bundled.

## Performance decision and limits

The approved reference is **539f130da148d1a802925d02363996f82ae4a323**. It excludes
the unavailable unpublished 0.0.12 changes. All 74 reference runtime inputs match
Git and both builds share the same 41 hosted dependency versions. The legacy
monitor detachment defect is corrected in the harness; diagnostics states never
share a process. The invalid historical mixed-state speedups remain withdrawn.

The combined exact-binary results put release tasks at **−3.1%**, and monitored
notification/fan-out/scope workloads at **−5.0% / −5.2% / −2.4%**. Release scopes
without diagnostics remain **+1.3%**, or **+0.030 µs per lifetime**; profile scopes
are −0.1%. Positive logic cells, all raw rounds and warmup methodology remain
visible in [PERFORMANCE.md](PERFORMANCE.md).

UI timings are less stable. Pooled release unmonitored build/raster medians are
+6.9%/+6.4%; pooled monitored build p95 is +37.9%. That large p95 spike does not
repeat in the second identical-binary matrix. Isolated CPU profiles show similar
Levit sampling shares on both revisions and do not establish an additional Levit
hot spot behind the varying engine tails. Those slower samples are retained;
no universal UI-tail, cold-start, mobile/browser or production-throughput parity
is certified. Coverage is line coverage, not a proof of general cancellation
safety. Cancellation remains cooperative and cleanup still waits for completion.

The investigated runtime regressions and functional/packaging gates are signed
off with these explicit measured limits. **Publication remains a separate action.**
