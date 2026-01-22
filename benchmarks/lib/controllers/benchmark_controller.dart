import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:levit_dart/levit_dart.dart';

import '../benchmark_engine.dart';
import '../benchmarks/logic/async_computed.dart';
import '../benchmarks/logic/batch_benchmark.dart';
import '../benchmarks/logic/complex_graph.dart';
import '../benchmarks/logic/fan_in.dart';
import '../benchmarks/logic/fan_out.dart';
import '../benchmarks/logic/rapid_mutation.dart';
import '../benchmarks/logic/scoped_di.dart';
import '../benchmarks/ui/animated_state.dart';
import '../benchmarks/ui/deep_tree.dart';
import '../benchmarks/ui/dynamic_grid.dart';
import '../benchmarks/ui/large_list.dart';
import '../runners/benchmark_runner.dart';

class AppBenchmarkController extends LevitController {
  final runner = BenchmarkRunner();

  // Selected Frameworks
  late LxSet<Framework> selectedFrameworks;

  // Results
  late LxMap<String, List<BenchmarkResult>> results;

  // State
  late LxVar<bool> isRunning;
  late LxVar<String> currentStatus;
  late LxVar<double> progress; // 0.0 to 1.0

  // Widget for active UI benchmarks
  late LxVar<WidgetBuilder?> activeBenchmarkWidget;

  final List<Benchmark> availableBenchmarks = [
    // Logic Benchmarks
    RapidMutationBenchmark(),
    ComplexGraphBenchmark(),
    FanOutBenchmark(),
    FanInBenchmark(),
    AsyncComputedBenchmark(),
    BatchVsUnBatchedBenchmark(),
    ScopedDIBenchmark(),
    // UI Benchmarks
    LargeListBenchmark(),
    DeepTreeBenchmark(),
    DynamicGridBenchmark(),
    AnimatedStateBenchmark(),
  ];

  @override
  void onInit() {
    super.onInit();

    selectedFrameworks = LxSet(Framework.values.toSet());
    results = LxMap({});
    isRunning = LxVar(false);
    currentStatus = LxVar('Ready');
    progress = LxVar(0.0);
    activeBenchmarkWidget = LxVar(null);
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
      buffer.writeln('| Framework | Time (µs) | Status |');
      buffer.writeln('|---|---|---|');

      final sortedResults = List<BenchmarkResult>.from(results[benchName]!)
        ..sort((a, b) => a.durationMicros.compareTo(b.durationMicros));

      for (final res in sortedResults) {
        final status = res.success ? 'OK' : 'Error: ${res.error}';
        buffer.writeln(
            '| ${res.framework.label} | ${res.durationMicros} | $status |');
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
