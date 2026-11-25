# Reproducing these measurements

Generated run artifacts were removed during cleanup on 2026-11-24. Historical artifact paths refer to Git commit `bd1a095`.


Use Dart 3.12.2 / Flutter 3.44.8. Match the dependency locks and hashes in
comparison-inputs.json (`comparison-inputs.json`). Run measurements only after all
builds and test processes have ended. The native app needs an unlocked, awake
macOS display: it waits for real engine frame timings and verifies display size,
pixel ratio and refresh rate across processes. Do not substitute debug frames.

1. Extract baseline-source.tar.gz into a new checkout. In its benchmarks folder,
   run `flutter pub get --offline`. For each of `--profile` and `--release`,
   run `flutter build macos --no-pub MODE -t lib/release_performance.dart
   --dart-define=LEVIT_REFERENCE=before`.
2. Build both modes in the candidate's benchmarks folder in the same way, using
   `--dart-define=LEVIT_REFERENCE=candidate`. For the release reference use
   the preserved 539f130 performance checkout and harness with the tested
   teardown patch, and `--dart-define=LEVIT_REFERENCE=539f130`.
3. From the candidate root, run the existing
   native comparison driver (`../../../../benchmarks/tool/compare_release_performance.py`):
   `python3 benchmarks/tool/compare_release_performance.py REFERENCE_ROOT
   NEW_OUTPUT_DIRECTORY BEFORE_ROOT`. It runs two passes in reverse revision
   order, two build modes and two diagnostics settings: 24 independent processes.
   The driver rejects incomplete reports and mismatched display geometry.
4. For sparse edits, suffix shifts, bulk writes and churn, compile the same
   [pure Dart workload](../../../../packages/core/levit_reactive/benchmark/collection_addresses.dart)
   against each checkout's package configuration with `dart compile exe
   --packages=benchmarks/.dart_tool/package_config.json PATH_TO_WORKLOAD
   -o OUTPUT_BINARY`. Run before, after, after, before. Each executable emits
   its sample durations and recomputation counts as JSON.
5. For retention rather than speed, run `dart test
   test/collections/entry_contract_test.dart` in levit_reactive. It checks idle
   channel counts, nullable addresses, binding, partial writes and dynamic/static
   reactivation; elapsed times are not assertions.

The [candidate record](CANDIDATE.md) links the gates and describes which
comparisons actually finished. A source archive alone is not a certificate.
