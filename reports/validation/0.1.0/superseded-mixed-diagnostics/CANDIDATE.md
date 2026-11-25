# Levit 0.1.0 candidate certification

Generated run artifacts were removed during cleanup on 2026-11-24. Historical artifact paths refer to Git commit `bd1a095`.


**Certified on 2026-11-11; not published.** All eight revised milestones and
release gates are complete. This is a coordinated, publish-ready source candidate
validated with local dependencies resolved together. The original uncommitted
checkout was preserved; no commit, tag or publication was performed.

## Candidate identity

The isolated candidate contains **873 source files** and **23 dependency
lockfiles**: 22 workspace packages plus the private root tool package. All 10
publishable runtime, kit, lint and inspector packages are version **0.1.0**.
Inspector UI source remains private; persistence remains on the independent
ecosystem roadmap under the approved M7 revision.

- Source archive (`../../../build/release_0.1.0/4c6b6f64dfac2f0b/levit-0.1.0-source.tar.gz`): 15,369,747 bytes, stored in the checkout's ignored build directory.
- Source manifest (`candidate-source.sha256`): SHA-256 `4c6b6f64dfac2f0bbd8f32dfe30519e51bfd4ec51652ddc7543334eb3f9da1bf`.
- Archive SHA-256: `d129add1b389bf36ee2166ce5dac00a60ed35743e80eb3781d89f6bb6b683f47`.
- Dependency manifest (`candidate-dependencies.sha256`): SHA-256 `c532e4fc9cf2bcafde7976cfc989baa31d7de50dbe3962d87598e23896ccd6e5`.
- Machine-readable certification (`candidate-certification.json`), gate results (`candidate-gates.json`), local package graph (`candidate-package-graph.json`).

The archive includes the exact source inventory, dependency locks and embedded
`SOURCE.sha256` / `DEPENDENCY_LOCKS.sha256`. Every archived source/lock byte was
read back and verified against those manifests. Deleted files, symlinks, ignored
generated files, Git metadata and `reports/validation/` evidence are excluded
from the source digest. Evidence remains beside this document. Bundled inspector
web assets are included. The temporary build root is recorded for investigation,
but the source archive and manifests do not depend on that temporary directory.

The final documentation sync copied only the benchmark README, release plan and
progress report into the validated snapshot. Runtime and build inputs matched
before archiving. No runtime Dart source changed during this certification
follow-up; harness fixes and packaging reproducibility corrections are detailed
below. Local dependency overrides use relative paths and were checked to resolve
inside the isolated snapshot.

## Validation

Toolchain: **Dart 3.12.2 / Flutter 3.44.8** on macOS 26.6.2, Apple M1 Pro.

| Gate | Final result | Evidence |
| --- | --- | --- |
| Coordinated dependency setup | Root plus all 22 workspace packages resolve offline; all local edges stay inside the candidate | Bootstrap (`candidate-bootstrap.log`), graph (`candidate-package-graph.json`) |
| Formatting | 578 Dart files, zero changes | Format (`candidate-snapshot-format.log`) |
| Fatal-info analysis | Entire candidate and aggregate package analysis pass | Analysis (`candidate-root-analysis.log`), CI (`candidate-ci.log`) |
| Native lint plugin, Dart and Flutter suites | All pass, including real consumer plugin loading, Nexus commands and two-client convergence | CI (`candidate-ci.log`) |
| Existing 100% coverage gate | **6,508 / 6,508 executable lines across 11 packages**; threshold and exclusions unchanged | Coverage (`candidate-coverage.log`) |
| Browser compilation | All five targets pass: public Dart kit, catalog, save/upload, session replacement and inspector | Browser builds (`candidate-browser-builds.log`) |
| Inspector release bundle | Clean rebuild matches all staged assets byte for byte | Assets (`candidate-assets.log`), rebuild (`candidate-inspector-rebuild.log`) |
| Stress | Runtime and Flutter stress suites pass | Stress (`candidate-stress.log`) |
| Benchmark harness | All 66 tests pass; six focused cleanup/frame regressions also pass after the frame-ID correction | Harness (`candidate-benchmarks.log`), focused regressions (`candidate-runner-regressions.log`) |
| Native performance | Eight successful profile/release processes; 8,640 samples and 2,880 matched frames, diagnostics off/on | Runs (`performance-runs.log`), [comparison](PERFORMANCE.md) |
| Publication preparation | All 10 publishable packages pass dry-run; final inspector dry-run has zero warnings | Dry-runs (`candidate-publish-dry-run.log`), inspector file list (`candidate-cli-final-dry-run.log`) |
| Installed inspector CLI | Isolated global activation; HTML, JavaScript and bundled fonts served with only Dart on PATH; awaited interrupt shutdown exits 0 | Consumer checks (`candidate-cli-consumer.json`), activation (`candidate-cli-activation.log`) |
| Migration and package boundaries | Removed APIs absent from implementation/consumer source; negative API and observation contracts pass in CI/coverage; private UI and ecosystem boundary verified | Migration checks (`candidate-migration-checks.json`), [M1–M4 acceptance](../SIGNOFF_M1_M4.md) |

Commands include `dart format --output=none --set-exit-if-changed .`,
`dart analyze --fatal-infos`, `dart run scripts/ci.dart`,
`dart run scripts/check_coverage.dart --fail-under=100 --timeout=600`,
`dart run scripts/check_browser_builds.dart`, `dart run scripts/stress_test.dart`,
`dart run melos run benchmarks --no-select` and
`dart run scripts/publish_dry_run.dart`. Native builds/runs follow the benchmark
README. All commands ran against the isolated candidate with its local graph.
The final native host/frame-wait adjustments were checked by fatal-info analysis,
formatting, both native builds and all eight native runs; they do not change the
runtime package source exercised by aggregate CI/coverage.

## Fixes made during certification

- Await benchmark teardown, unmount UI on failures and reject results when cleanup
  fails. Six regressions verify cleanup failures and delayed frame batches.
- Read every computed consumer on fan-out updates, preventing lazy invalidation
  from silently reducing the measured work.
- Match Flutter timing batches by engine frame ID, excluding warmups and waiting
  for complete release-mode batches. Native frame waits are bounded; missing
  executables, wrong revision labels and incomplete frame counts fail the runner.
- Apply identical process-scoped activity and window-visibility controls to both
  native hosts. Earlier idle/visibility-distorted probes are retained separately.
  No system power preference was changed; assertions/windows end with each process.
- Exclude Flutter's nondeterministic `.last_build_id` from the inspector bundle;
  verify a clean rebuild reproduces the remaining assets. Generated IDE files
  were removed from the isolated packaging input.
- Normalize root script formatting under the freshly resolved Dart 3.12 language
  configuration. Coverage behavior, threshold and exclusions are unchanged.

## Performance and approved reference change

The user explicitly approved **`539f130da148d1a802925d02363996f82ae4a323`** as the
comparison reference because the original unpublished 0.0.12 archive is missing.
This excludes the unpublished baseline changes; differences cannot be assigned
solely to the 0.1.0 milestones. All 74 reference package source/manifests match
Git; both sides use the same workload, host and 44 external dependency versions.
The reference adapter and exact setup are retained with the [comparison](PERFORMANCE.md).

In release mode with diagnostics off, notification latency improves **88.9%** and
computed fan-out **46.9%**. Scope lifetimes cost **18.4% more**; leaf tasks take
**4.83 µs versus 1.62 µs**, about **3.2 µs extra per task**. With diagnostics on,
notification/fan-out workloads take roughly **2.7–2.8×** the reference and scope
lifetimes **5.8×**. These material costs remain visible as release tradeoffs;
monitoring history/statistics are opt-in. UI wall medians remain near 8.33 ms,
with candidate build p95 at or below 2.53 ms in this experiment. No unmeasured
performance threshold or blanket speedup claim is part of this certification.

## Limits and publication boundary

- Performance evidence covers one native macOS host. Normal desktop background
  apps remained running; small differences within round variation are inconclusive.
  Browser checks establish compilation, not interactive browser/mobile performance.
- Diagnostic measurements use JSON/UTF-8 serialization into a counting sink, with
  a 10,000-event history and no optional task bridge. They do not measure network
  transport latency or prove retained-memory behavior.
- Coverage is executable line coverage, not branch coverage or a proof of general
  cancellation safety. The acceptance matrix records the tested failure paths.
- Dry-runs use coordinated local overrides because the 0.1.0 packages are not yet
  published. Pub emits expected override hints; hosted resolution and server-side
  publication checks remain part of the separate publication action.
- The source archive is a local, unsigned candidate artifact. Publishing, release
  tagging and hosted rollout require a separate user instruction.

[Progress report](../../../release_0.1.0_progress.md) ·
[Cumulative migration guide](../../../../docs/MIGRATION_0.1.0.md) ·
[Ecosystem roadmap](../../../ecosystem_roadmap.md)
