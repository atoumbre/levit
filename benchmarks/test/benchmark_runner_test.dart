@Timeout(Duration(minutes: 5))

library;

import 'package:benchmarks/benchmark_discovery.dart';
import 'package:benchmarks/benchmark_config.dart';
import 'package:benchmarks/benchmark_environment.dart';
import 'package:benchmarks/benchmark_engine.dart';
import 'package:benchmarks/runners/benchmark_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'headless_benchmark_runner.dart';

void main() {
  BenchmarkConfig.useTestProfile();
  final runner = HeadlessBenchmarkRunner(
    iterations: 8,
    warmupIterations: 2,
  );
  final environment = BenchmarkEnvironment.capture(
    executionContext: 'flutter_test',
    benchmarkProfile: BenchmarkConfig.profileName,
    iterations: runner.iterations,
    warmupIterations: runner.warmupIterations,
    frameworks: Framework.values,
    benchmarks: BenchmarkDiscovery.allBenchmarks,
  );

  final results = <String, List<BenchmarkResult>>{};

  group('Headless Benchmarks', () {
    for (final benchmark in BenchmarkDiscovery.allBenchmarks) {
      group(benchmark.name, () {
        for (final framework in Framework.values) {
          if (benchmark.isUI) {
            testWidgets(framework.label, (tester) async {
              final result =
                  await runner.runUIBenchmark(tester, benchmark, framework);
              _printResult(result);
              _addResult(results, result);
              expect(result.success, true, reason: result.error);
            });
          } else {
            test(framework.label, () async {
              final result =
                  await runner.runLogicBenchmark(benchmark, framework);
              _printResult(result);
              _addResult(results, result);
              expect(result.success, true, reason: result.error);
            });
          }
        }
      });
    }

    tearDownAll(() {
      BenchmarkConfig.useProductionProfile();
      print(BenchmarkReporter.generateConsoleReport(
        results: results,
        title: 'Benchmark Consolidated Report',
        environment: environment,
      ));
    });
  });
}

void _addResult(
    Map<String, List<BenchmarkResult>> results, BenchmarkResult result) {
  if (!results.containsKey(result.benchmarkName)) {
    results[result.benchmarkName] = [];
  }
  results[result.benchmarkName]!.add(result);
}

void _printResult(BenchmarkResult result) {
  if (result.success) {
    print(
        'RESULT: ${result.benchmarkName} [${result.framework.label}]: ${result.durationMicros}µs (${result.durationMs.toStringAsFixed(3)}ms)');
  } else {
    print(
        'ERROR: ${result.benchmarkName} [${result.framework.label}]: ${result.error}');
  }
}
