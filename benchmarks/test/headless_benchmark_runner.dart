// ignore_for_file: avoid_print

import 'package:benchmarks/benchmark_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class HeadlessBenchmarkRunner {
  static const int defaultIterations = 50;
  static const int defaultWarmupIterations = 3;

  final int iterations;
  final int warmupIterations;

  HeadlessBenchmarkRunner({
    this.iterations = defaultIterations,
    this.warmupIterations = defaultWarmupIterations,
  });

  /// Runs a logic benchmark without any UI.
  Future<BenchmarkResult> runLogicBenchmark(
    Benchmark benchmark,
    Framework framework,
  ) async {
    final impl = benchmark.createImplementation(framework);
    final samples = <int>[];
    bool success = true;
    String? error;

    try {
      await impl.setup();

      for (int i = 0; i < warmupIterations; i++) {
        await impl.run();
        await impl.verify();
      }

      for (int i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();
        await impl.run();
        stopwatch.stop();
        await impl.verify();
        samples.add(stopwatch.elapsedMicroseconds);
        // Small yield to avoid blocking everything
        await Future.delayed(Duration.zero);
      }
    } catch (e, stack) {
      success = false;
      error = '$e\n$stack';
      print('Error running ${benchmark.name} for ${framework.label}: $e');
    } finally {
      try {
        await impl.teardown();
      } catch (e) {
        print('Error tearing down ${benchmark.name}: $e');
      }
    }

    return BenchmarkResult(
      framework: framework,
      benchmarkName: benchmark.name,
      classification: benchmark.classification,
      comparisonNote: benchmark.comparisonNote,
      samplesMicros: success ? samples : const [],
      warmupIterations: warmupIterations,
      success: success,
      error: error,
    );
  }

  /// Runs a UI benchmark using WidgetTester.
  Future<BenchmarkResult> runUIBenchmark(
    WidgetTester tester,
    Benchmark benchmark,
    Framework framework,
  ) async {
    final impl = benchmark.createImplementation(framework);
    final samples = <int>[];
    bool success = true;
    String? error;

    try {
      await impl.setup();

      // Mount the widget
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) => impl.build(context)),
        ),
      ));

      // Allow layout/paint to settle
      await tester.pumpAndSettle();

      for (int i = 0; i < warmupIterations; i++) {
        await impl.run();
        await tester.pump();
        await impl.verify();
      }

      for (int i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();
        await impl.run(); // Triggers state change
        await tester.pump(); // Force rebuild/frame
        stopwatch.stop();

        await impl.verify();
        samples.add(stopwatch.elapsedMicroseconds);
      }

      // Unmount
      await tester.pumpWidget(const SizedBox.shrink());
    } catch (e, stack) {
      success = false;
      error = '$e\n$stack';
      print('Error running ${benchmark.name} for ${framework.label}: $e');
    } finally {
      try {
        await impl.teardown();
      } catch (e) {
        print('Error tearing down ${benchmark.name}: $e');
      }
    }

    return BenchmarkResult(
      framework: framework,
      benchmarkName: benchmark.name,
      classification: benchmark.classification,
      comparisonNote: benchmark.comparisonNote,
      samplesMicros: success ? samples : const [],
      warmupIterations: warmupIterations,
      success: success,
      error: error,
    );
  }
}
