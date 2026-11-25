import 'package:benchmarks/benchmark_engine.dart';
import 'package:benchmarks/runners/benchmark_runner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'headless_benchmark_runner.dart';

class BrokenBenchmark extends Benchmark {
  BrokenBenchmark({this.isUI = false});
  @override
  final bool isUI;
  @override
  String get name => 'cleanup failure';
  @override
  String get description => 'Retains failure after all cleanup attempts';
  @override
  BenchmarkImplementation createImplementation(Framework framework) =>
      BrokenWork();
}

class BrokenWork extends BenchmarkImplementation {
  @override
  Future<void> setup() async {}
  @override
  Future<void> run() async {}
  @override
  Future<void> teardown() async => throw StateError('teardown failed');
  @override
  Widget build(BuildContext context) => const Text('mounted');
}

void main() {
  test('app runner rejects a measured run whose cleanup fails', () async {
    final result = await BenchmarkRunner().runBenchmark(
      BrokenBenchmark(),
      Framework.levit,
      iterations: 1,
      warmupIterations: 0,
    );
    expect(result.success, isFalse);
    expect(result.samplesMicros, isEmpty);
    expect(result.error, contains('teardown failed'));
  });
  test('headless logic runner reports cleanup failure', () async {
    final result = await HeadlessBenchmarkRunner(
      iterations: 1,
      warmupIterations: 0,
    ).runLogicBenchmark(BrokenBenchmark(), Framework.levit);
    expect(result.success, isFalse);
    expect(result.samplesMicros, isEmpty);
  });
  testWidgets('headless UI runner unmounts and reports cleanup failure', (
    tester,
  ) async {
    final result = await HeadlessBenchmarkRunner(
      iterations: 1,
      warmupIterations: 0,
    ).runUIBenchmark(tester, BrokenBenchmark(isUI: true), Framework.levit);
    expect(result.success, isFalse);
    expect(find.text('mounted'), findsNothing);
  });
}
