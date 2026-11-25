# Reproducing the collection comparison

Generated run artifacts were removed during cleanup on 2026-11-24. Historical artifact paths refer to Git commit `bd1a095`.


Use Dart 3.12.2 and Flutter 3.44.8 on macOS arm64. Restore the release reference from the existing performance checkout, the frozen pre-redesign checkout from its archive, and the previous candidate from its archive. The input manifest records package and executable identities. Comparison inputs (`inputs.json`) · Frozen checkout and dependency locks (`../collection-redesign/baseline.json`) · Previous candidate archive (`../collection-redesign/candidate-archive.json`)

## Focused AOT

1. Resolve each checkout’s benchmark package with its recorded lock. Use the current checkout’s unchanged `packages/core/levit_reactive/benchmark/collection_addresses.dart` as the input for every compilation.
2. For the 539f130 focused build, copy its reactive library into a temporary directory. Apply the return-annotation patch from that directory with `patch -p1`. Point a copy of the benchmark package configuration at this reactive library, resolving all other package roots against the original configuration. This preserves its synchronous implementation and lets the common workload await every close. Type adaptation (`reference-close-types.patch`)
3. Use `dart compile exe --packages=CONFIG WORKLOAD -o BINARY` for each of the four configurations. Run a complete binary per process. Start with candidate, previous candidate, pre-redesign, reference. Rotate the order left one position in each of four rounds. Run those four rounds backwards and reverse the execution order within each. Preserve all nine measured samples for each workload and check its evaluation count.
4. To reproduce the separate CPU diagnostics, copy the sampler to a file named `profile.dart`. Run `dart --enable-vm-service=0 --profiler --packages=CONFIG profile.dart WORKLOAD OUTPUT.json` with the reactive test package configuration on the previous and fixed candidates. Use `shift` and `churn` separately. These are JIT profiles. The released-speed comparisons use the AOT binaries. Sampler (`cpu_profile.dart.txt`)

## Native matrix

Finish builds and tests before measuring. Build the Flutter benchmark app with the explicit release-performance entrypoint on **each** checkout. An existing app in the correct build directory may contain a different entrypoint. In the checkout’s benchmarks directory run both commands with the corresponding label (`539f130`, `before` or `candidate`).

```sh
flutter build macos --profile --no-pub -t lib/release_performance.dart --dart-define=LEVIT_REFERENCE=LABEL
flutter build macos --release --no-pub -t lib/release_performance.dart --dart-define=LEVIT_REFERENCE=LABEL
```

Use an awake, unlocked graphical session. From the candidate repository root, run the display-checking wrapper with a new output directory. It calls the existing driver with the same arguments and checks each complete launch against the recorded 1600 × 1200, 2×, 120 Hz display. A launch on another display is saved and repeated, regardless of its timing. Four consecutive geometry mismatches abort that case.

```sh
caffeinate -di python3 reports/validation/0.1.0/collection-performance/run_native.py REFERENCE_ROOT OUTPUT PRE_REDESIGN_ROOT
```

The driver reverses revision order for the second pass and validates the announced revision, build mode, diagnostics state, observer completion, warmups, measured frame IDs and geometry. Each process reports three rounds of five workloads. The follow-up summary takes the median of the three round medians in each process before comparing the two independent launches. Driver (`../../../../benchmarks/tool/compare_release_performance.py`)
