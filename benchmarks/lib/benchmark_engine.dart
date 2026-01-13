import 'package:flutter/widgets.dart';

/// Represents a state management framework being benchmarked.
enum Framework {
  vanilla,
  levit,
  getx,
  bloc,
  riverpod;

  String get label => switch (this) {
        levit => 'Levit',
        vanilla => 'Vanilla',
        getx => 'GetX',
        bloc => 'BLoC',
        riverpod => 'Riverpod',
      };
}

/// A single result from a benchmark iteration.
class BenchmarkResult {
  final Framework framework;
  final String benchmarkName;
  final int durationMicros; // Changed from durationMs
  final bool success;
  final String? error;

  BenchmarkResult({
    required this.framework,
    required this.benchmarkName,
    required this.durationMicros,
    this.success = true,
    this.error,
  });

  double get durationMs => durationMicros / 1000.0;

  @override
  String toString() =>
      '$framework - $benchmarkName: ${durationMs.toStringAsFixed(2)}ms';
}

/// Abstract base class for all benchmarks.
abstract class Benchmark {
  String get name;
  String get description;

  /// Whether this benchmark measures UI performance or pure logic.
  bool get isUI;

  /// Creates the framework-specific implementation.
  BenchmarkImplementation createImplementation(Framework framework);
}

/// Framework-specific implementation of a benchmark.
abstract class BenchmarkImplementation {
  /// Setup any necessary state.
  Future<void> setup();

  /// Run the benchmark iteration. Returns duration in microseconds.
  /// For UI benchmarks, this should trigger the state change.
  Future<int> run();

  /// Teardown/Cleanup.
  Future<void> teardown();

  /// For UI benchmarks, provides the widget tree to render.
  Widget build(BuildContext context) => const SizedBox();
}
