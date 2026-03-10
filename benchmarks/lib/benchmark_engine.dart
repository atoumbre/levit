import 'dart:math' as math;

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

/// Indicates how strongly a benchmark supports cross-framework comparison.
enum BenchmarkClassification {
  comparative,
  approximate,
  featureDemo;

  String get label => switch (this) {
        comparative => 'Comparative',
        approximate => 'Approximate',
        featureDemo => 'Feature Demo',
      };
}

/// A single result from a benchmark iteration.
class BenchmarkResult {
  final Framework framework;
  final String benchmarkName;
  final BenchmarkClassification classification;
  final String? comparisonNote;
  final List<int> samplesMicros;
  final int warmupIterations;
  final bool success;
  final String? error;

  BenchmarkResult({
    required this.framework,
    required this.benchmarkName,
    required this.classification,
    required this.samplesMicros,
    required this.warmupIterations,
    this.success = true,
    this.error,
    this.comparisonNote,
  });

  int get iterations => samplesMicros.length;

  int get durationMicros => medianMicros;

  double get durationMs => durationMicros / 1000.0;

  double get meanMicros {
    if (samplesMicros.isEmpty) return 0;
    final total = samplesMicros.fold<int>(0, (sum, value) => sum + value);
    return total / samplesMicros.length;
  }

  int get medianMicros {
    if (samplesMicros.isEmpty) return 0;
    final sorted = [...samplesMicros]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return ((sorted[middle - 1] + sorted[middle]) / 2).round();
  }

  int get minMicros => samplesMicros.isEmpty ? 0 : samplesMicros.reduce(_min);

  int get maxMicros => samplesMicros.isEmpty ? 0 : samplesMicros.reduce(_max);

  double get stdDevMicros {
    if (samplesMicros.length < 2) return 0;
    final mean = meanMicros;
    final squaredDiffs = samplesMicros.fold<double>(
      0,
      (sum, value) => sum + (value - mean) * (value - mean),
    );
    return math.sqrt(squaredDiffs / samplesMicros.length);
  }

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

  /// Indicates whether the benchmark is suitable for headline rankings.
  BenchmarkClassification get classification =>
      BenchmarkClassification.comparative;

  /// Short caveat to print alongside the benchmark results when needed.
  String? get comparisonNote => null;

  /// Creates the framework-specific implementation.
  BenchmarkImplementation createImplementation(Framework framework);
}

/// Framework-specific implementation of a benchmark.
abstract class BenchmarkImplementation {
  /// Setup any necessary state.
  Future<void> setup();

  /// Run a full benchmark iteration and await any framework-specific settling.
  Future<void> run();

  /// Validate post-conditions after an iteration.
  Future<void> verify() async {}

  /// Teardown/Cleanup.
  Future<void> teardown();

  /// For UI benchmarks, provides the widget tree to render.
  Widget build(BuildContext context) => const SizedBox();
}

int _min(int a, int b) => a < b ? a : b;

int _max(int a, int b) => a > b ? a : b;
