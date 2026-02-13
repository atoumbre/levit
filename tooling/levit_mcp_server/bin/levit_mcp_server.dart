import 'dart:io';

import 'package:levit_mcp_server/levit_mcp_server.dart';

Future<void> main() async {
  final server = LevitMcpServer();
  await server.serve(stdin, stdout);
}
