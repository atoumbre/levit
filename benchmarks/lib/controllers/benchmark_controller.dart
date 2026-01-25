import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:levit_dart_core/levit_dart_core.dart';

import '../benchmark_engine.dart';
import '../benchmark_discovery.dart';
import '../runners/benchmark_runner.dart';
import '../runners/benchmark_reporter.dart';

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

  final List<Benchmark> availableBenchmarks = BenchmarkDiscovery.allBenchmarks;

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
    final report = BenchmarkReporter.generateMarkdownReport(
      results: results,
      title: 'Benchmark Results',
    );

    await Clipboard.setData(ClipboardData(text: report));

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
