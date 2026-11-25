// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'benchmark_config.dart';
import 'benchmark_discovery.dart';
import 'benchmark_engine.dart';
import 'benchmark_environment.dart';
import 'runners/benchmark_reporter.dart';
import 'runners/benchmark_runner.dart';

/// Exercises the actual app runner and engine timings, which widget tests
/// cannot supply. This short production-size run validates contracts, not speed.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Levit.enableAutoLinking();
  BenchmarkConfig.useProductionProfile();
  final host = GlobalKey<_HostState>();
  runApp(MaterialApp(home: _Host(key: host)));
  await WidgetsBinding.instance.endOfFrame;
  final results = <String, List<BenchmarkResult>>{};
  final environment = BenchmarkEnvironment.capture(
    executionContext:
        'native app contract smoke (not a performance comparison)',
    benchmarkProfile: BenchmarkConfig.profileName,
    iterations: 2,
    warmupIterations: 1,
    frameworks: Framework.values,
    benchmarks: BenchmarkDiscovery.allBenchmarks,
  );
  var failed = false;
  try {
    for (final benchmark in BenchmarkDiscovery.allBenchmarks) {
      for (final framework in Framework.values) {
        final result = await BenchmarkRunner().runBenchmark(
          benchmark,
          framework,
          iterations: 2,
          warmupIterations: 1,
          mountWidget: host.currentState!.mount,
        );
        (results[benchmark.name] ??= []).add(result);
        if (!result.success ||
            (benchmark.isUI && result.frameTimings.length != 2)) {
          failed = true;
          print(
            'FAILED: ${benchmark.name} / ${result.displayLabel}: ${result.error}',
          );
        }
      }
    }
    final report = BenchmarkReporter.generateJsonReport(
      results: results,
      environment: environment,
    );
    // Emit through the inherited log stream: a sandboxed macOS application
    // cannot write an arbitrary repository path without user-selected access.
    print('APP_BENCHMARK_JSON: ${jsonEncode(jsonDecode(report))}');
    print(
      'APP_BENCHMARK_SMOKE: ${failed ? 'FAIL' : 'PASS'} (${results.values.expand((r) => r).length} cases)',
    );
  } catch (error, stack) {
    failed = true;
    print('$error\n$stack');
  } finally {
    await host.currentState!.mount((_) => const SizedBox.shrink());
    await Levit.reset(force: true);
  }
  exit(failed ? 1 : 0);
}

class _Host extends StatefulWidget {
  const _Host({super.key});
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  WidgetBuilder builder = (_) => const SizedBox.shrink();

  Future<void> mount(WidgetBuilder next) async {
    setState(() => builder = next);
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 5),
    );
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Builder(builder: builder));
}
