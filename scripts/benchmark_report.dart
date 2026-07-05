import 'dart:io';

import 'src/process_runner.dart';

Future<void> main() async {
  print('Running headless benchmarks and generating report...');

  final result = await runProcess(
    [
      'flutter',
      'test',
      'tool/generate_benchmark_report.dart',
      '--reporter=compact',
    ],
    workingDirectory: 'benchmarks',
    timeout: const Duration(minutes: 10),
  );

  if (result.timedOut) {
    print('Benchmark report generation timed out.');
    _printCapturedOutput(result);
    exit(1);
  }

  if (result.exitCode != 0) {
    print('Benchmark report generation failed.');
    _printCapturedOutput(result);
    exit(result.exitCode);
  }

  print('Benchmark report generated: reports/bench_mark_report.md');
}

void _printCapturedOutput(ProcessOutcome result) {
  if (result.stdout.trim().isNotEmpty) {
    print(result.stdout.trimRight());
  }
  if (result.stderr.trim().isNotEmpty) {
    print(result.stderr.trimRight());
  }
}
