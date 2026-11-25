import 'package:benchmarks/benchmark_config.dart';
import 'package:benchmarks/benchmark_engine.dart';
import 'package:benchmarks/benchmarks/logic/async_computed.dart';
import 'package:benchmarks/benchmarks/logic/batch_benchmark.dart';
import 'package:benchmarks/benchmarks/logic/complex_graph.dart';
import 'package:benchmarks/benchmarks/logic/computed_chain.dart';
import 'package:benchmarks/benchmarks/logic/fan_in.dart';
import 'package:benchmarks/benchmarks/logic/fan_out.dart';
import 'package:benchmarks/computed_mode_benchmarks.dart';
import 'package:benchmarks/runners/benchmark_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  setUpAll(BenchmarkConfig.useTestProfile);
  tearDownAll(BenchmarkConfig.useProductionProfile);

  test('existing dashboard modes remain unchanged', () {
    expect(LevitGraphBenchmark().staticDeps, isTrue);
    expect(LevitAsyncComputedBenchmark().staticDeps, isTrue);
    expect(LevitFanInBenchmark().staticDeps, isFalse);
    expect(LevitFanOutBenchmark().staticDeps, isFalse);
    expect(LevitBatchBenchmark().staticDeps, isFalse);
    expect(LevitComputedChain().staticDeps, isFalse);
  });

  for (final mode in ComputedDependencyMode.values) {
    for (final benchmark in ComputedModeBenchmark.all(mode)) {
      test('${mode.label}: ${benchmark.name} preserves delivery', () async {
        final work = benchmark.createImplementation(Framework.levit);
        await work.setup();
        try {
          for (var iteration = 1; iteration <= 3; iteration++) {
            await work.run();
            // Inspect delivery captured inside run, before verification can read
            // a producer. Diamond run itself checks every individual root write.
            switch (work) {
              case LevitFanInBenchmark():
                expect(
                  work.observed.value,
                  BenchmarkConfig.fanInInputs + iteration,
                );
                expect(work.observed.count, iteration);
              case LevitFanOutBenchmark():
                expect(
                  work.lastValues,
                  List.generate(
                    BenchmarkConfig.fanOutDependents,
                    (i) => iteration + i,
                  ),
                );
                expect(work.deliveries, everyElement(iteration));
              case LevitComputedChain():
                final updates =
                    iteration * BenchmarkConfig.computedChainRunIterations;
                expect(
                  work.observedLeaf,
                  updates + BenchmarkConfig.computedChainIterations,
                );
                expect(work.deliveries, updates);
              case LevitBatchBenchmark():
                expect(
                  work.observedSum,
                  iteration * BenchmarkConfig.batchIterations,
                );
                expect(work.notifyCount, 1);
              case LevitAsyncComputedBenchmark():
                expect(
                  work.asyncComputed.valueOrNull,
                  'Result: ${iteration * BenchmarkConfig.asyncComputedIterations}',
                );
              case LevitGraphBenchmark():
                expect(
                  work.expectedA,
                  iteration * BenchmarkConfig.complexGraphIterations,
                );
              default:
                fail('Add a delivery assertion for ${work.runtimeType}');
            }
            await work.verify();
          }
        } finally {
          await work.teardown();
        }
      });
    }

    test(
      '${mode.label}: runner records explicit mode and valid samples',
      () async {
        final result = await BenchmarkRunner().runBenchmark(
          ComputedModeBenchmark.all(mode)[2],
          Framework.levit,
          iterations: 2,
          warmupIterations: 1,
        );
        expect(result.success, isTrue, reason: result.error);
        expect(result.samplesMicros, hasLength(2));
        expect(result.toJson()['implementation'], 'Levit (${mode.label})');
      },
    );
  }
}
