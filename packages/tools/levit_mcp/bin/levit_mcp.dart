import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/stdio.dart';
import 'package:levit_mcp/levit_mcp.dart';

Future<void> main(List<String> args) async {
  final LevitMcpConfig? config;
  try {
    config = LevitMcpConfig.parseArgs(args, environment: Platform.environment);
  } on FormatException catch (error) {
    stderr
      ..writeln('Error: ${error.message}')
      ..writeln()
      ..writeln(LevitMcpConfig.usage);
    exitCode = 64;
    return;
  }

  if (config == null) {
    stderr.writeln(LevitMcpConfig.usage);
    return;
  }

  final server = await LevitMcpServer.start(
    config: config,
    channel: stdioChannel(input: stdin, output: stdout),
    logSink: stderr,
  );

  final signalSubscriptions = <StreamSubscription<ProcessSignal>>[];
  void watchSignal(ProcessSignal signal) {
    signalSubscriptions.add(
      signal.watch().listen((_) {
        unawaited(server.close());
      }),
    );
  }

  watchSignal(ProcessSignal.sigint);
  if (!Platform.isWindows) {
    watchSignal(ProcessSignal.sigterm);
  }

  try {
    await server.done;
  } finally {
    for (final sub in signalSubscriptions) {
      await sub.cancel();
    }
    await server.close();
  }
}
