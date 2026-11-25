import 'dart:async';
import 'dart:io';
import 'package:levit_devtools/levit_devtools.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout.writeln(
      'Levit local inspector\nUsage: levit_devtools [--port 9200]\nRead-only UI: http://127.0.0.1:9200\nProducer endpoint: ws://127.0.0.1:9200/ws',
    );
    return;
  }
  var port = 9200;
  if (arguments.isNotEmpty) {
    if (arguments.length != 2 ||
        arguments.first != '--port' ||
        int.tryParse(arguments.last) == null) {
      stderr.writeln('Use --help for supported options.');
      exitCode = 64;
      return;
    }
    port = int.parse(arguments.last);
    if (port < 0 || port > 65535) {
      stderr.writeln('Invalid port');
      exitCode = 64;
      return;
    }
  }
  final server = LevitInspectorServer(
    assets: await LevitInspectorServer.bundledAssets(),
  );
  try {
    await server.start(port: port);
  } catch (error) {
    stderr.writeln('Could not start inspector: $error');
    exitCode = 1;
    return;
  }
  stdout.writeln('Levit inspector: ${server.uri}');
  final stopped = Completer<void>();
  final subscriptions = [
    ProcessSignal.sigint.watch().listen((_) {
      if (!stopped.isCompleted) stopped.complete();
    }),
    ProcessSignal.sigterm.watch().listen((_) {
      if (!stopped.isCompleted) stopped.complete();
    }),
  ];
  await stopped.future;
  for (final subscription in subscriptions) {
    await subscription.cancel();
  }
  await server.close();
}
