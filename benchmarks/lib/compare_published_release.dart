// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_harness.dart';
import 'benchmark_config.dart';
import 'benchmark_discovery.dart';
import 'benchmark_engine.dart';
import 'benchmark_environment.dart';
import 'computed_mode_benchmarks.dart';
import 'runners/benchmark_runner.dart';
import 'runners/benchmark_reporter.dart';

/// Runs one unchanged dashboard workload per process for a revision comparison.
Future<void> main() async {
  if (kDebugMode) throw StateError('Use a profile or release build.');
  final name = Platform.environment['LEVIT_COMPARISON_WORKLOAD'];
  final mode = Platform.environment['LEVIT_COMPARISON_MODE'] ?? 'default';
  final benchmarks = mode == 'default'
      ? BenchmarkDiscovery.allBenchmarks
      : ComputedModeBenchmark.all(
          ComputedDependencyMode.values.singleWhere((m) => m.label == mode),
        );
  final benchmark = benchmarks.singleWhere((b) => b.name == name);
  BenchmarkConfig.useProductionProfile();
  var failed = false;
  try {
    final controller = await mountBenchmarkDashboard();
    controller.isRunning.value = true;
    controller.currentStatus.value = '${benchmark.name}: $mode';
    final environment = BenchmarkEnvironment.capture(
      executionContext: 'app-published-release-comparison',
      benchmarkProfile: BenchmarkConfig.profileName,
      iterations: BenchmarkRunner.defaultIterations,
      warmupIterations: BenchmarkRunner.defaultWarmupIterations,
      frameworks: [Framework.levit],
      benchmarks: [benchmark],
    );
    final result = await controller.runner.runBenchmark(
      benchmark,
      Framework.levit,
      mountWidget: (builder) async {
        controller.activeBenchmarkWidget.value = builder;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
    );
    failed = !result.success || result.iterations != 50;
    final report =
        jsonDecode(
              BenchmarkReporter.generateJsonReport(
                results: {
                  benchmark.name: [result],
                },
                environment: environment,
              ),
            )
            as Map<String, dynamic>;
    report['dependencyMode'] = mode;
    print('PUBLISHED_COMPARISON_JSON:${jsonEncode(report)}');
  } catch (error, stack) {
    failed = true;
    print('PUBLISHED_COMPARISON_FAILED: $error\n$stack');
  } finally {
    await unmountBenchmarkDashboard();
  }
  exit(failed ? 1 : 0);
}
