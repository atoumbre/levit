import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ProcessOutcome {
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;

  const ProcessOutcome({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.timedOut,
  });
}

Future<ProcessOutcome> runProcess(
  List<String> command, {
  required String workingDirectory,
  Duration? timeout,
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
    exitCode = timeout == null
        ? await process.exitCode
        : await process.exitCode.timeout(timeout);
  } on TimeoutException {
    timedOut = true;
    process.kill(ProcessSignal.sigterm);
    exitCode = -1;
  }

  final stdout = await stdoutFuture;
  final stderr = await stderrFuture;

  return ProcessOutcome(
    exitCode: exitCode,
    stdout: stdout,
    stderr: stderr,
    timedOut: timedOut,
  );
}
