// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_harness.dart';
import 'benchmark_config.dart';
import 'benchmark_engine.dart';
import 'benchmark_environment.dart';
import 'computed_mode_benchmarks.dart';
import 'runners/benchmark_runner.dart';
import 'runners/benchmark_reporter.dart';

/// One dependency mode per process; both modes run from the same AOT binary.
Future<void> main() async {
  if (kDebugMode) throw StateError('Use a profile or release build.');
  final mode = ComputedDependencyMode.values.singleWhere(
    (mode) => mode.label == Platform.environment['LEVIT_COMPUTED_MODE'],
    orElse: () =>
        throw ArgumentError('Set LEVIT_COMPUTED_MODE=dynamic|static.'),
  );
  final reverse = Platform.environment['LEVIT_COMPUTED_REVERSE'] == '1';
  final selection = Platform.environment['LEVIT_COMPUTED_WORKLOAD'];
  BenchmarkConfig.useProductionProfile();
  final cases = ComputedModeBenchmark.all(mode)
      .where((benchmark) => selection == null || benchmark.name == selection)
      .toList();
  final expectedCases = selection == null ? 6 : 1;
  if (cases.length != expectedCases) {
    throw ArgumentError('Unknown computed workload: $selection');
  }
  final benchmarks = reverse ? cases.reversed.toList() : cases;
  var failed = false;
  try {
    final controller = await mountBenchmarkDashboard();
    controller.isRunning.value = true;
    final environment = BenchmarkEnvironment.capture(
      executionContext: 'app-computed-modes',
      benchmarkProfile: BenchmarkConfig.profileName,
      iterations: BenchmarkRunner.defaultIterations,
      warmupIterations: BenchmarkRunner.defaultWarmupIterations,
      frameworks: [Framework.levit],
      benchmarks: benchmarks,
    );
    for (final benchmark in benchmarks) {
      controller.currentStatus.value =
          '${benchmark.name}: ${mode.label} dependencies';
      final result = await controller.runner.runBenchmark(
        benchmark,
        Framework.levit,
      );
      controller.results[benchmark.name] = [result];
    }
    final results = controller.results.values.expand((r) => r).toList();
    failed =
        results.length != expectedCases ||
        results.any((r) => !r.success || r.iterations != 50);
    final report =
        jsonDecode(
              BenchmarkReporter.generateJsonReport(
                results: controller.results,
                environment: environment,
              ),
            )
            as Map<String, dynamic>;
    report['dependencyMode'] = mode.label;
    report['workloadOrder'] = reverse ? 'reverse' : 'forward';
    report['workloadSelection'] = selection;
    report['workloadConfig'] = {
      'diamondUpdates': BenchmarkConfig.complexGraphIterations,
      'fanOutDependents': BenchmarkConfig.fanOutDependents,
      'fanInInputs': BenchmarkConfig.fanInInputs,
      'asyncUpdates': BenchmarkConfig.asyncComputedIterations,
      'batchUpdates': BenchmarkConfig.batchIterations,
      'chainDepth': BenchmarkConfig.computedChainIterations,
      'chainUpdates': BenchmarkConfig.computedChainRunIterations,
    };
    print('COMPUTED_COMPARISON_JSON:${jsonEncode(report)}');
  } catch (error, stack) {
    failed = true;
    print('COMPUTED_COMPARISON_FAILED: $error\n$stack');
  } finally {
    await unmountBenchmarkDashboard();
  }
  exit(failed ? 1 : 0);
}
