// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import '../benchmark_engine.dart';

class BenchmarkRunner {
  static const int defaultIterations = 50;
  static const int defaultWarmupIterations = 5;

  /// Runs a specific benchmark for a specific framework.
  /// Measures each iteration in the runner to keep timing consistent.
  Future<BenchmarkResult> runBenchmark(
    Benchmark benchmark,
    Framework framework, {
    int iterations = defaultIterations,
    int warmupIterations = defaultWarmupIterations,
    Future<void> Function(WidgetBuilder builder)? mountWidget,
  }) async {
    final impl = benchmark.createImplementation(framework);
    final samples = <int>[];
    bool success = true;
    String? error;

    try {
      print('Running ${benchmark.name} for ${framework.label}...');
      await impl.setup();

      if (benchmark.isUI) {
        if (mountWidget == null) {
          throw 'UI Benchmark requires mountWidget callback';
        }

        // Mount the widget once for the session (or per iteration? Per session is better for "update" benchmarks)
        // For these benchmarks (list update), we want to measure the update on an already mounted widget.
        await mountWidget((context) => impl.build(context));

        // Allow layout/paint to settle
        await Future.delayed(const Duration(milliseconds: 200));

        for (int i = 0; i < warmupIterations; i++) {
          await impl.run();
          await _waitForFrame();
          await impl.verify();
        }

        for (int i = 0; i < iterations; i++) {
          // Ensure we are stable
          await Future.delayed(const Duration(milliseconds: 16));

          final stopwatch = Stopwatch()..start();
          await impl.run(); // Triggers setState/notifyListeners

          await _waitForFrame(); // Wait for rasterization/build
          stopwatch.stop();

          await impl.verify();
          samples.add(stopwatch.elapsedMicroseconds);
        }

        // Unmount
        await mountWidget((context) => const SizedBox.shrink());
      } else {
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
          await Future.delayed(const Duration(milliseconds: 10));
        }
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

  Future<void> _waitForFrame() {
    final completer = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    return completer.future;
  }

  /// Runs all frameworks for a given benchmark.
  Stream<BenchmarkResult> runAllFrameworks(Benchmark benchmark) async* {
    final frameworks = [...Framework.values];
    final offset = benchmark.name.length % frameworks.length;
    final rotated = [
      ...frameworks.skip(offset),
      ...frameworks.take(offset),
    ];

    for (final fw in rotated) {
      if (benchmark.isUI && fw == Framework.riverpod) {
        // Example: if a framework isn't supported for a benchmark, handle it.
        // For now assuming all supported.
      }
      yield await runBenchmark(benchmark, fw);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }
}
