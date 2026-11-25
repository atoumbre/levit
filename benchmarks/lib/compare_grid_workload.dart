// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'app_harness.dart';
import 'benchmarks/ui/dynamic_grid.dart';
import 'runners/benchmark_reporter.dart';

/// Isolate the existing grid case using the dashboard's normal selection API.
/// Its position in the full suite is 10: both selections use framework offset 0.
Future<void> main() async {
  if (kDebugMode) throw StateError('Use a profile or release build.');
  var failed = false;
  try {
    final controller = await mountBenchmarkDashboard();
    controller.selectedBenchmarks
      ..clear()
      ..addAll(
        controller.availableBenchmarks.whereType<DynamicGridBenchmark>(),
      );
    await controller.runAll();
    final results = controller.results.values.expand((r) => r).toList();
    failed =
        results.length != 5 ||
        results.any((r) => !r.success || r.iterations != 50);
    print(
      'APP_COMPARISON_JSON:${jsonEncode(jsonDecode(BenchmarkReporter.generateJsonReport(results: controller.results, environment: controller.lastEnvironment.value)))}',
    );
  } catch (error, stack) {
    failed = true;
    print('APP_COMPARISON_FAILED: $error\n$stack');
  } finally {
    await unmountBenchmarkDashboard();
  }
  exit(failed ? 1 : 0);
}
