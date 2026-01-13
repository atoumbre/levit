// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import '../benchmark_engine.dart';

class BenchmarkRunner {
  /// Runs a specific benchmark for a specific framework.
  /// Returns the raw duration in microseconds.
  Future<BenchmarkResult> runBenchmark(
    Benchmark benchmark,
    Framework framework, {
    int iterations = 50,
    Future<void> Function(WidgetBuilder builder)? mountWidget,
  }) async {
    final impl = benchmark.createImplementation(framework);
    int totalDuration = 0;
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

        // Warmup
        await impl.run();
        await _waitForFrame();

        for (int i = 0; i < iterations; i++) {
          // Ensure we are stable
          await Future.delayed(const Duration(milliseconds: 16));

          final stopwatch = Stopwatch()..start();
          await impl.run(); // Triggers setState/notifyListeners

          await _waitForFrame(); // Wait for rasterization/build
          stopwatch.stop();

          totalDuration += stopwatch.elapsedMicroseconds;
        }

        // Unmount
        await mountWidget((context) => const SizedBox.shrink());
      } else {
        // Headless execution
        await impl.run(); // Warmup

        for (int i = 0; i < iterations; i++) {
          final duration = await impl.run();
          totalDuration += duration;
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

    // Average duration
    final avgDuration = success ? (totalDuration ~/ iterations) : 0;

    return BenchmarkResult(
      framework: framework,
      benchmarkName: benchmark.name,
      durationMicros: avgDuration,
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
    for (final fw in Framework.values) {
      if (benchmark.isUI && fw == Framework.riverpod) {
        // Example: if a framework isn't supported for a benchmark, handle it.
        // For now assuming all supported.
      }
      yield await runBenchmark(benchmark, fw);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }
}
