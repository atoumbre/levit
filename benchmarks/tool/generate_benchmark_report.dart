// ignore_for_file: avoid_print

import 'dart:io';

import 'package:benchmarks/benchmark_config.dart';
import 'package:benchmarks/benchmark_discovery.dart';
import 'package:benchmarks/benchmark_engine.dart';
import 'package:benchmarks/benchmark_environment.dart';
import 'package:benchmarks/runners/benchmark_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/headless_benchmark_runner.dart';

void main() {
  BenchmarkConfig.useTestProfile();

  final runner = HeadlessBenchmarkRunner(
    iterations: 100,
    warmupIterations: 50,
  );
  final environment = BenchmarkEnvironment.capture(
    executionContext: 'flutter_test_report',
    benchmarkProfile: BenchmarkConfig.profileName,
    iterations: runner.iterations,
    warmupIterations: runner.warmupIterations,
    frameworks: Framework.values,
    benchmarks: BenchmarkDiscovery.allBenchmarks,
    frameworkOrderRotation: true,
    includeHostName: false,
  );
  final results = <String, List<BenchmarkResult>>{};

  group('Benchmark report generation', () {
    final frameworks = [...Framework.values];
    var i = 0;
    for (final benchmark in BenchmarkDiscovery.allBenchmarks) {
      final offset = i % frameworks.length;
      final rotatedFrameworks = [
        ...frameworks.skip(offset),
        ...frameworks.take(offset),
      ];
      i++;

      group(benchmark.name, () {
        for (final framework in rotatedFrameworks) {
          if (benchmark.isUI) {
            testWidgets(framework.label, (tester) async {
              final result =
                  await runner.runUIBenchmark(tester, benchmark, framework);
              _addResult(results, result);
              expect(result.success, true, reason: result.error);
            });
          } else {
            test(framework.label, () async {
              final result =
                  await runner.runLogicBenchmark(benchmark, framework);
              _addResult(results, result);
              expect(result.success, true, reason: result.error);
            });
          }
        }
      });
    }

    tearDownAll(() async {
      BenchmarkConfig.useProductionProfile();
      final report = BenchmarkReporter.generateMarkdownReport(
        results: results,
        title: 'Benchmark Results',
        environment: environment,
      );
      final reportFile = File('../reports/bench_mark_report.md');
      await reportFile.writeAsString(report);
      print('Benchmark report generated: ${reportFile.absolute.path}');
    });
  });
}

void _addResult(
  Map<String, List<BenchmarkResult>> results,
  BenchmarkResult result,
) {
  results.putIfAbsent(result.benchmarkName, () => []).add(result);
}
