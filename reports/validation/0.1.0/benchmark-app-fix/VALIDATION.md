# Benchmark app methodology correction — 2026-11-11

Generated run artifacts were removed during cleanup on 2026-11-24. Historical artifact paths refer to Git commit `bd1a095`.


The interactive benchmark app now times completed observable work. The supplied
2026-11-11 app report predates this correction and must not be compared with
methodology 2 results as a runtime performance delta.

## Changes

- Fan-in consumes the sum during timing, and fan-out consumes every dependent
  on every iteration. Captured values/counts are checked before verification in
  permanent regressions. Rapid mutation waits for every listener delivery.
- Diamond/chain consumers observe every source update, and the batching demo
  consumes its final aggregate inside timing. Approximate/demo classifications
  remain explicit; intermediate work is not identical across these primitives.
- Reports and charts identify RxDart, ValueNotifier and custom-map substitutes.
- UI wall time is labeled update-to-frame-end. Build/raster p50 and p95 use
  matched engine frames; JSON exports retain raw samples and environment data.
- The virtualized list changes a visible row. Keyed grid replacement verifies
  actual mount/unmount. Nested-leaf and progress-bar names no longer claim
  propagation through reactive ancestors or sustained 60 fps.
- The measurement surface has no unrelated spinner and retains full layout
  size. A dashboard regression also caught and fixed sidebar text overflow and
  a background that hid Material ink effects.

## Validation

Installed Dart 3.12.2 / Flutter 3.44.8:

| Check | Result | Evidence |
| --- | --- | --- |
| Complete benchmark test suite | 104 passed, including 37 new regressions | tests.log (`tests.log`) |
| Fatal-info analysis | No issues | analyze.log (`analyze.log`) |
| Formatting | 34 files, zero changes | format.log (`format.log`) |
| Native smoke release build | Passed | native-smoke-build.log (`native-smoke-build.log`) |
| Production-size app-runner smoke | All 60 framework/workload cases passed; 120 wall samples, 40 matched engine frames | raw JSON (`native-smoke.json`), log (`native-smoke.log`) |
| Interactive dashboard release build | Passed; restored the normal app entrypoint | dashboard-build.log (`dashboard-build.log`) |

The smoke uses one warmup and two measured iterations per case. It validates
completion, cleanup, production workload sizes and actual frame-timing delivery;
it is not statistical performance evidence. No tests/builds ran concurrently
with its execution. Its first attempt passed workload checks but could not write
JSON into the repository from the sandboxed macOS application. Output now uses
the inherited process log, and the complete rerun passed without changing
entitlements or sandbox policy. The host Xcode placeholder-device warning was
non-fatal in both successful release builds.

Source identities are recorded in benchmark-source.sha256 (`benchmark-source.sha256`)
and validation.json (`validation.json`). The smoke's build-time revision field is
explicitly `unrecorded`; it is not a frozen candidate certification. Retain the
manifest and lockfile alongside results when reproducing this validation.

All 80 package-library Dart files match the prior archived candidate at
`/private/tmp/levit-0.1.0-performance-x773iaob`. The independent
`release_performance.dart` and `measured_frames.dart` are also unchanged. Earlier
candidate certification and baseline-comparison evidence still identify their
archived snapshot; they do not include this later benchmark-app correction.
No publication, commit, tag, or new runtime-performance sign-off was performed.
