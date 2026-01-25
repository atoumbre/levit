import 'dart:io';
import 'package:dev_tool_server/dev_tool_server.dart';

void main(List<String> args) async {
  final port = int.tryParse(args.isNotEmpty ? args[0] : '9200') ?? 9200;

  final server = DevToolController(port: port);
  await server.start();

  // Handle signals to shutdown gracefully
  ProcessSignal.sigint.watch().listen((_) async {
    print('Stopping DevTool Server...');
    await server.stop();
    exit(0);
  });
}
