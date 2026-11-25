import 'benchmark_engine.dart';
import 'benchmarks/logic/async_computed.dart';
import 'benchmarks/logic/batch_benchmark.dart';
import 'benchmarks/logic/complex_graph.dart';
import 'benchmarks/logic/computed_chain.dart';
import 'benchmarks/logic/fan_in.dart';
import 'benchmarks/logic/fan_out.dart';

enum ComputedDependencyMode {
  dynamicTracking(false, 'dynamic'),
  staticTracking(true, 'static');

  const ComputedDependencyMode(this.staticDeps, this.label);

  final bool staticDeps;
  final String label;
}

/// Reuses each dashboard workload with only its dependency-tracking flag changed.
/// All six have fixed dependency sets. Default dashboard selections are separate.
class ComputedModeBenchmark extends Benchmark {
  ComputedModeBenchmark._(this.definition, this.mode, this._create);

  final Benchmark definition;
  final ComputedDependencyMode mode;
  final BenchmarkImplementation Function(bool staticDeps) _create;

  static List<ComputedModeBenchmark> all(ComputedDependencyMode mode) => [
    ComputedModeBenchmark._(
      ComplexGraphBenchmark(),
      mode,
      (value) => LevitGraphBenchmark(staticDeps: value),
    ),
    ComputedModeBenchmark._(
      FanOutBenchmark(),
      mode,
      (value) => LevitFanOutBenchmark(staticDeps: value),
    ),
    ComputedModeBenchmark._(
      FanInBenchmark(),
      mode,
      (value) => LevitFanInBenchmark(staticDeps: value),
    ),
    ComputedModeBenchmark._(
      AsyncComputedBenchmark(),
      mode,
      (value) => LevitAsyncComputedBenchmark(staticDeps: value),
    ),
    ComputedModeBenchmark._(
      BatchVsUnBatchedBenchmark(),
      mode,
      (value) => LevitBatchBenchmark(staticDeps: value),
    ),
    ComputedModeBenchmark._(
      ComputedChainBenchmark(),
      mode,
      (value) => LevitComputedChain(staticDeps: value),
    ),
  ];

  @override
  String get name => definition.name;

  @override
  String get description => definition.description;

  @override
  bool get isUI => definition.isUI;

  @override
  BenchmarkClassification get classification => definition.classification;

  @override
  String? get comparisonNote => definition.comparisonNote;

  @override
  String implementationLabel(Framework framework) => 'Levit (${mode.label})';

  @override
  BenchmarkImplementation createImplementation(Framework framework) {
    if (framework != Framework.levit) {
      throw ArgumentError('Computed mode comparison only supports Levit.');
    }
    return _create(mode.staticDeps);
  }
}
