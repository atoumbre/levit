import 'dart:io';

import 'src/process_runner.dart';

Future<void> main(List<String> args) async {
  final phases = <_Phase>[
    _Phase(
      name: 'analysis',
      command: [
        'dart',
        'run',
        'melos',
        'exec',
        '--concurrency=6',
        '--',
        'dart',
        'analyze',
        '--fatal-infos',
      ],
    ),
    _Phase(
      name: 'dart tests',
      command: [
        'dart',
        'run',
        'melos',
        'exec',
        '--concurrency=1',
        '--dir-exists=test',
        '--no-depends-on=flutter',
        '--ignore=levit_stress_tests',
        '--ignore=dev_tool_server',
        '--',
        'dart',
        'test',
      ],
    ),
    _Phase(
      name: 'flutter tests',
      command: [
        'dart',
        'run',
        'melos',
        'exec',
        '--concurrency=1',
        '--dir-exists=test',
        '--depends-on=flutter',
        '--ignore=levit_stress_tests',
        '--ignore=benchmarks',
        '--ignore=flutter_dev_tool',
        '--',
        'flutter',
        'test',
      ],
    ),
  ];

  for (final phase in phases) {
    final startedAt = DateTime.now();
    print('Running ${phase.name}...');
    final result = await runProcess(
      phase.command,
      workingDirectory: Directory.current.path,
      timeout: const Duration(minutes: 15),
    );

    final elapsed = DateTime.now().difference(startedAt);
    if (result.timedOut) {
      print('${phase.name} timed out after ${_formatDuration(elapsed)}.');
      _printCapturedOutput(result);
      exit(1);
    }
    if (result.exitCode != 0) {
      print('${phase.name} failed after ${_formatDuration(elapsed)}.');
      _printCapturedOutput(result);
      exit(result.exitCode);
    }
    print('${phase.name} passed in ${_formatDuration(elapsed)}.');
  }

  print('CI checks passed.');
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  if (minutes == 0) return '${seconds}s';
  return '${minutes}m ${seconds}s';
}

void _printCapturedOutput(ProcessOutcome result) {
  if (result.stdout.trim().isNotEmpty) {
    print('\nstdout:\n${result.stdout.trimRight()}');
  }
  if (result.stderr.trim().isNotEmpty) {
    print('\nstderr:\n${result.stderr.trimRight()}');
  }
}

class _Phase {
  final String name;
  final List<String> command;

  const _Phase({
    required this.name,
    required this.command,
  });
}
