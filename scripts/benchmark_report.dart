import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  print('Running headless benchmarks and generating report...');

  final result = await _runProcess(
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

void _printCapturedOutput(_ProcessOutcome result) {
  if (result.stdout.trim().isNotEmpty) {
    print(result.stdout.trimRight());
  }
  if (result.stderr.trim().isNotEmpty) {
    print(result.stderr.trimRight());
  }
}

class _ProcessOutcome {
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;

  const _ProcessOutcome({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.timedOut,
  });
}

Future<_ProcessOutcome> _runProcess(
  List<String> command, {
  required String workingDirectory,
  required Duration timeout,
}) async {
  final process = await Process.start(
    command.first,
    command.sublist(1),
    workingDirectory: workingDirectory,
  );

  final stdoutFuture = process.stdout.transform(utf8.decoder).join();
  final stderrFuture = process.stderr.transform(utf8.decoder).join();

  int exitCode;
  var timedOut = false;
  try {
    exitCode = await process.exitCode.timeout(timeout);
  } on TimeoutException {
    timedOut = true;
    process.kill(ProcessSignal.sigterm);
    exitCode = -1;
  }

  final stdout = await stdoutFuture;
  final stderr = await stderrFuture;

  return _ProcessOutcome(
    exitCode: exitCode,
    stdout: stdout,
    stderr: stderr,
    timedOut: timedOut,
  );
}
