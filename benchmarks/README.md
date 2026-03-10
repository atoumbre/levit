# Benchmark App

This app compares Levit with several state-management stacks under a shared
benchmark harness.

## Methodology

- The runner owns timing for every benchmark. Implementations no longer return
  their own durations.
- Every benchmark performs warmup iterations before measured samples.
- Every measured iteration must finish its framework-specific work before the
  sample is recorded.
- Every measured iteration is followed by a correctness check. A benchmark run
  fails if the expected state was not reached.
- Reports use per-iteration samples and publish median, mean, min/max, standard
  deviation, and sample count.
- Reports also include environment metadata: build mode, benchmark profile,
  iteration counts, OS/runtime details, CPU thread count, locale, selected
  frameworks/benchmarks, and display metrics when available.
- UI workloads use deterministic mutation schedules.
- UI list/grid benchmarks mutate the same plain backing collections across all
  frameworks and use the framework only for notification/rebuild.

## Benchmark Classes

- `Comparative`: Suitable for headline cross-framework comparison.
- `Approximate`: Uses the closest available primitive when a framework does not
  expose the same abstraction directly.
- `Feature Demo`: Demonstrates a feature that is not a first-class primitive in
  every framework. Do not use these for headline rankings.

## Test Profile

The automated test suite uses a reduced benchmark profile so the harness can be
validated quickly in CI:

- `flutter test test/benchmark_runner_test.dart`

Production defaults remain in `lib/benchmark_config.dart`.

## Running The App

- `flutter run -d macos`

The in-app dashboard rotates framework order per benchmark to reduce simple
fixed-order bias.

## Reading Results

- Prefer median over mean for ranking.
- Check standard deviation before treating small deltas as meaningful.
- Treat `Approximate` and `Feature Demo` results as directional, not definitive.
