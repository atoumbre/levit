// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'app_harness.dart';
import 'benchmark_engine.dart';
import 'benchmarks/logic/computed_chain.dart';
import 'benchmarks/logic/fan_in.dart';
import 'benchmarks/logic/fan_out.dart';
import 'benchmarks/ui/dynamic_grid.dart';

/// Sampling profiler entrypoint. Runs the existing fixture body repeatedly;
/// tight logic loops collect CPU samples, not comparable latency measurements.
Future<void> main() async {
  if (!kProfileMode) throw StateError('Use a profile build.');
  final controller = await mountBenchmarkDashboard();
  var busy = false;
  registerExtension('ext.levit.profile', (_, parameters) async {
    if (busy) throw StateError('A profile is already running');
    busy = true;
    final name = parameters['workload']!;
    final framework = Framework.values.byName(
      parameters['framework'] ?? 'levit',
    );
    final Benchmark benchmark = switch (name) {
      'chain' => ComputedChainBenchmark(),
      'fanin' => FanInBenchmark(),
      'fanout' => FanOutBenchmark(),
      'grid' => DynamicGridBenchmark(),
      _ => throw ArgumentError.value(name),
    };
    final work = benchmark.createImplementation(framework);
    controller.isRunning.value = true;
    controller.currentStatus.value =
        'Profiling ${benchmark.name}: ${framework.label}';
    var iterations = 0;
    final watch = Stopwatch();
    try {
      await work.setup();
      if (benchmark.isUI) {
        controller.activeBenchmarkWidget.value = work.build;
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      for (var i = 0; i < 5; i++) {
        await work.run();
        if (benchmark.isUI) await WidgetsBinding.instance.endOfFrame;
        await work.verify();
      }
      watch.start();
      while (watch.elapsedMilliseconds < 8000) {
        if (benchmark.isUI) {
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }
        await work.run();
        if (benchmark.isUI) await WidgetsBinding.instance.endOfFrame;
        await work.verify();
        iterations++;
        if (!benchmark.isUI && iterations % 100 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      return ServiceExtensionResponse.result(
        jsonEncode({
          'workload': name,
          'framework': framework.name,
          'iterations': iterations,
          'elapsedUs': watch.elapsedMicroseconds,
          'profileOnly': true,
        }),
      );
    } finally {
      if (benchmark.isUI) {
        controller.activeBenchmarkWidget.value = (_) => const SizedBox.shrink();
        await WidgetsBinding.instance.endOfFrame;
      }
      await work.teardown();
      controller.activeBenchmarkWidget.value = null;
      controller.isRunning.value = false;
      busy = false;
    }
  });
  print('LEVIT_PROFILE_READY');
}
