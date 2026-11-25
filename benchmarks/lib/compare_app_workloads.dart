// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'app_harness.dart';
import 'runners/benchmark_reporter.dart';

/// Automates the actual dashboard's complete, unchanged 50-sample comparison.
Future<void> main() async {
  if (kDebugMode) throw StateError('Use a profile or release build.');
  var failed = false;
  try {
    final controller = await mountBenchmarkDashboard();
    await controller.runAll();
    final results = controller.results.values.expand((r) => r).toList();
    failed =
        results.length != 60 ||
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
