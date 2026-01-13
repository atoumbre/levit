import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:levit_dart/levit_dart.dart';

import 'package:flutter/services.dart';
import '../benchmark_engine.dart';
import '../benchmarks/rapid_mutation.dart';
import '../benchmarks/complex_graph.dart';
import '../benchmarks/large_list.dart';
import '../benchmarks/deep_tree.dart';
import '../benchmarks/fan_out.dart';
import '../benchmarks/fan_in.dart';
import '../benchmarks/dynamic_grid.dart';
import '../benchmarks/async_computed.dart';
import '../benchmarks/batch_benchmark.dart';
import '../benchmarks/scoped_di.dart';
import '../benchmarks/animated_state.dart';
import '../runners/benchmark_runner.dart';

class AppBenchmarkController extends LevitController {
  final runner = BenchmarkRunner();

  // Selected Frameworks
  late LxSet<Framework> selectedFrameworks;

  // Results
  late LxMap<String, List<BenchmarkResult>> results;

  // State
  late LxVal<bool> isRunning;
  late LxVal<String> currentStatus;
  late LxVal<double> progress; // 0.0 to 1.0

  // Widget for active UI benchmarks
  late LxVal<WidgetBuilder?> activeBenchmarkWidget;

  final List<Benchmark> availableBenchmarks = [
    // Logic Benchmarks
    RapidMutationBenchmark(),
    ComplexGraphBenchmark(),
    FanOutBenchmark(),
    FanInBenchmark(),
    AsyncComputedBenchmark(),
    BatchVsUnbatchedBenchmark(),
    // UI Benchmarks
    LargeListBenchmark(),
    DeepTreeBenchmark(),
    DynamicGridBenchmark(),
    ScopedDIBenchmark(),
    AnimatedStateBenchmark(),
  ];

  @override
  void onInit() {
    super.onInit();

    selectedFrameworks = LxSet(Framework.values.toSet());
    results = LxMap({});
    isRunning = LxVal(false);
    currentStatus = LxVal('Ready');
    progress = LxVal(0.0);
    activeBenchmarkWidget = LxVal(null);
  }

  Future<void> _mountWidget(WidgetBuilder builder) async {
    activeBenchmarkWidget.value = builder;
    // Wait for the UI to rebuild and mount the active widget
    // We add a delay to allow the frame to process
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> runAll() async {
    if (isRunning.value) return;
    isRunning.value = true;
    results.clear();
    progress.value = 0.0;

    final frameworks = selectedFrameworks.toList();
    final benchmarks = availableBenchmarks;
    final totalSteps = frameworks.length * benchmarks.length;
    int completedSteps = 0;

    for (final benchmark in benchmarks) {
      currentStatus.value = 'Benchmark: ${benchmark.name}';

      for (final fw in frameworks) {
        currentStatus.value = 'Running ${benchmark.name} on ${fw.label}...';

        // Run
        final result =
            await runner.runBenchmark(benchmark, fw, mountWidget: _mountWidget);

        // Store
        Lx.batch(() {
          if (!results.containsKey(benchmark.name)) {
            results[benchmark.name] = [];
          }
          results[benchmark.name]!.add(result);
        });

        completedSteps++;
        progress.value = completedSteps / totalSteps;
      }
    }

    // Ensure widget is cleared
    activeBenchmarkWidget.value = null;
    isRunning.value = false;
    currentStatus.value = 'Done!';
    progress.value = 1.0;
  }

  Future<void> copyResults() async {
    final buffer = StringBuffer();
    buffer.writeln('# Benchmark Results');
    buffer.writeln('Date: ${DateTime.now()}');
    buffer.writeln('');

    for (final benchName in results.keys) {
      buffer.writeln('## $benchName');
      buffer.writeln('| Framework | Time (ms) | Status |');
      buffer.writeln('|---|---|---|');

      final sortedResults = List<BenchmarkResult>.from(results[benchName]!)
        ..sort((a, b) => a.durationMicros.compareTo(b.durationMicros));

      for (final res in sortedResults) {
        final status = res.success ? 'OK' : 'Error: ${res.error}';
        buffer.writeln(
            '| ${res.framework.label} | ${res.durationMs.toStringAsFixed(3)} | $status |');
      }
      buffer.writeln('');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    currentStatus.value = 'Copied to clipboard!';
    await Future.delayed(const Duration(seconds: 2));
    if (!isRunning.value) {
      currentStatus.value = 'Ready';
    }
  }

  void toggleFramework(Framework fw) {
    if (selectedFrameworks.contains(fw)) {
      selectedFrameworks.remove(fw);
    } else {
      selectedFrameworks.add(fw);
    }
  }
}
