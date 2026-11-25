import 'package:benchmarks/controllers/benchmark_controller.dart';
import 'package:benchmarks/main.dart';
import 'package:benchmarks/benchmark_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  testWidgets(
    'measurement surface stays expanded without an animated spinner',
    (tester) async {
      Levit.enableAutoLinking();
      await tester.pumpWidget(const BenchmarkApp());
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Run All Benchmarks'));
      final controller = context.levit.find<AppBenchmarkController>();
      controller.activeBenchmarkWidget.value = (_) => const ColoredBox(
        key: ValueKey('measurement surface'),
        color: Colors.white,
      );
      await tester.pump();
      final surface = find.byKey(const ValueKey('measurement surface'));
      expect(tester.getSize(surface).width, greaterThan(100));
      expect(tester.getSize(surface).height, greaterThan(100));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byTooltip('Copy JSON with raw samples'), findsOneWidget);
      controller.activeBenchmarkWidget.value = null;
      final benchmark = controller.availableBenchmarks.first;
      final results = [
        for (final succeeded in [true, false])
          BenchmarkResult(
            framework: succeeded ? Framework.levit : Framework.vanilla,
            benchmarkName: benchmark.name,
            classification: benchmark.classification,
            samplesMicros: succeeded ? [100] : [],
            warmupIterations: 1,
            success: succeeded,
            error: succeeded ? null : 'cleanup failed',
          ),
      ];
      controller.results[benchmark.name] = results;
      await tester.pumpAndSettle();
      for (final result in results) {
        expect(find.textContaining(result.statusDescription), findsOneWidget);
      }
      expect(find.textContaining('Details: cleanup failed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await Levit.reset(force: true);
    },
  );
}
