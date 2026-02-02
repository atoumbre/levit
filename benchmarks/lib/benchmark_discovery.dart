import 'benchmark_engine.dart';
import 'benchmarks/logic/async_computed.dart';
import 'benchmarks/logic/batch_benchmark.dart';
import 'benchmarks/logic/complex_graph.dart';
import 'benchmarks/logic/computed_chain.dart';
import 'benchmarks/logic/fan_in.dart';
import 'benchmarks/logic/fan_out.dart';
import 'benchmarks/logic/rapid_mutation.dart';
import 'benchmarks/logic/scoped_di.dart';
import 'benchmarks/ui/animated_state.dart';
import 'benchmarks/ui/deep_tree.dart';
import 'benchmarks/ui/dynamic_grid.dart';
import 'benchmarks/ui/large_list.dart';

class BenchmarkDiscovery {
  static final List<Benchmark> allBenchmarks = [
    // Logic Benchmarks
    RapidMutationBenchmark(),
    ComplexGraphBenchmark(),
    FanOutBenchmark(),
    FanInBenchmark(),
    AsyncComputedBenchmark(),
    BatchVsUnBatchedBenchmark(),
    ScopedDIBenchmark(),
    ComputedChainBenchmark(),

    // UI Benchmarks
    LargeListBenchmark(),
    DeepTreeBenchmark(),
    DynamicGridBenchmark(),
    AnimatedStateBenchmark(),
  ];
}
