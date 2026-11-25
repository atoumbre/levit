import 'dart:convert';

import 'package:benchmarks/benchmark_config.dart';
import 'package:benchmarks/benchmark_engine.dart';
import 'package:benchmarks/benchmarks/logic/batch_benchmark.dart';
import 'package:benchmarks/benchmarks/logic/fan_in.dart';
import 'package:benchmarks/benchmarks/logic/fan_out.dart';
import 'package:benchmarks/benchmarks/logic/rapid_mutation.dart';
import 'package:benchmarks/benchmarks/logic/scoped_di.dart';
import 'package:benchmarks/benchmarks/ui/dynamic_grid.dart';
import 'package:benchmarks/benchmarks/ui/large_list.dart';
import 'package:benchmarks/benchmarks/ui/deep_tree.dart';
import 'package:benchmarks/benchmarks/ui/animated_state.dart';
import 'package:benchmarks/runners/benchmark_reporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(BenchmarkConfig.useTestProfile);
  tearDownAll(BenchmarkConfig.useProductionProfile);

  for (final framework in Framework.values) {
    test('${framework.label}: fan-in delivers before verification', () async {
      final work = FanInBenchmark().createImplementation(framework);
      await work.setup();
      try {
        for (var i = 1; i <= 3; i++) {
          await work.run();
          expect(
            (work as dynamic).observed.value,
            BenchmarkConfig.fanInInputs + i,
          );
          expect((work as dynamic).observed.count, i);
          await work.verify();
          expect((work as dynamic).observed.count, i);
        }
      } finally {
        await work.teardown();
      }
    });

    test(
      '${framework.label}: every fan-out consumer completes inside run',
      () async {
        final work = FanOutBenchmark().createImplementation(framework);
        await work.setup();
        try {
          for (var iteration = 1; iteration <= 3; iteration++) {
            await work.run();
            // These are captured consumer values, not reads of lazy producers.
            expect(
              (work as dynamic).lastValues,
              List.generate(
                BenchmarkConfig.fanOutDependents,
                (i) => iteration + i,
              ),
            );
            if (work is LevitFanOutBenchmark) {
              expect(work.deliveries, everyElement(iteration));
            }
            await work.verify();
          }
        } finally {
          await work.teardown();
        }
      },
    );

    test(
      '${framework.label}: mutation stream is fully delivered before return',
      () async {
        final work = RapidMutationBenchmark().createImplementation(framework);
        await work.setup();
        try {
          for (var iteration = 1; iteration <= 2; iteration++) {
            await work.run();
            final expected =
                iteration * BenchmarkConfig.rapidMutationIterations;
            expect((work as dynamic).observed.value, expected);
            expect((work as dynamic).observed.count, expected);
            await work.verify();
          }
        } finally {
          await work.teardown();
        }
      },
    );

    test(
      '${framework.label}: batch aggregate is consumed before verification',
      () async {
        final work = BatchVsUnBatchedBenchmark().createImplementation(
          framework,
        );
        await work.setup();
        try {
          await work.run();
          expect(
            (work as dynamic).observedSum,
            BenchmarkConfig.batchIterations,
          );
          await work.verify();
        } finally {
          await work.teardown();
        }
      },
    );

    testWidgets('${framework.label}: grid replaces keyed elements', (
      tester,
    ) async {
      final work = DynamicGridBenchmark().createImplementation(framework);
      await work.setup();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Builder(builder: work.build)),
          ),
        );
        expect(find.byKey(const ValueKey(0)), findsOneWidget);
        for (var i = 1; i <= 3; i++) {
          await work.run();
          await tester.pump();
          await work.verify();
          expect(find.byKey(ValueKey((i - 1) * 50)), findsNothing);
          expect(find.byKey(ValueKey(i * 50)), findsOneWidget);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        expect((work as dynamic).mountedItems, isEmpty);
        await work.teardown();
      }
    });

    testWidgets('${framework.label}: list mutation changes visible text', (
      tester,
    ) async {
      final work = LargeListBenchmark().createImplementation(framework);
      await work.setup();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Builder(builder: work.build)),
          ),
        );
        await work.run();
        await tester.pump();
        await work.verify();
        expect(find.text('Updated 0 #1'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await work.teardown();
      }
    });

    testWidgets(
      '${framework.label}: leaf and progress fixtures actually render updates',
      (tester) async {
        for (final benchmark in [
          DeepTreeBenchmark(),
          AnimatedStateBenchmark(),
        ]) {
          final work = benchmark.createImplementation(framework);
          await work.setup();
          try {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(body: Builder(builder: work.build)),
              ),
            );
            await work.run();
            await tester.pump();
            if (benchmark is DeepTreeBenchmark) {
              expect(find.text('Value: 1'), findsOneWidget);
            } else {
              expect(
                tester
                    .widget<FractionallySizedBox>(
                      find.byType(FractionallySizedBox),
                    )
                    .widthFactor,
                1 / 120,
              );
            }
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await work.teardown();
          }
        }
      },
    );
  }

  test(
    'report names actual primitives and separates frame timing from wall time',
    () {
      expect(FanOutBenchmark().implementationLabel(Framework.bloc), 'RxDart');
      expect(
        BatchVsUnBatchedBenchmark().implementationLabel(Framework.bloc),
        'ValueNotifier (substitute)',
      );
      expect(
        ScopedDIBenchmark().implementationLabel(Framework.bloc),
        'Custom map (substitute)',
      );
      final result = BenchmarkResult(
        framework: Framework.bloc,
        implementationLabel: 'RxDart',
        benchmarkName: 'fixture',
        classification: BenchmarkClassification.approximate,
        samplesMicros: [7000, 9000],
        frameTimings: [
          {'buildUs': 100, 'rasterUs': 200, 'totalUs': 800},
          {'buildUs': 300, 'rasterUs': 400, 'totalUs': 1000},
        ],
        measurement: 'Update to frame end',
        warmupIterations: 1,
      );
      final results = {
        'fixture': [
          result,
          BenchmarkResult(
            framework: Framework.levit,
            benchmarkName: 'fixture',
            classification: BenchmarkClassification.approximate,
            samplesMicros: const [],
            warmupIterations: 1,
            success: false,
            error: 'cleanup | failed\nstack trace',
          ),
        ],
      };
      final report = BenchmarkReporter.generateMarkdownReport(results: results);
      expect(report, contains('RxDart'));
      expect(report, isNot(contains('| BLoC |')));
      expect(report, contains('Update to frame end'));
      expect(report, contains('| RxDart | 100 | 300 | 200 | 400 | 2 |'));
      expect(report, contains('OK — ${result.statusAssessment}'));
      expect(
        report,
        contains('Error — ${results['fixture']!.last.statusAssessment}'),
      );
      expect(report, contains(r'cleanup \| failed<br>stack trace'));
      final console = BenchmarkReporter.generateConsoleReport(results: results);
      expect(console, contains(result.statusDescription));
      expect(console, contains('Details: cleanup | failed'));
      final raw = jsonDecode(
        BenchmarkReporter.generateJsonReport(results: results),
      );
      expect(raw['methodologyVersion'], 2);
      expect(raw['results'][0]['samplesMicros'], [7000, 9000]);
      expect(raw['results'][0]['frameTimings'], result.frameTimings);
      expect(raw['results'][0]['statusAssessment'], result.statusAssessment);
      expect(raw['results'][1]['error'], 'cleanup | failed\nstack trace');
    },
  );
}
