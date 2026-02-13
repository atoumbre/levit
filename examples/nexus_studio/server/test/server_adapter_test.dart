import 'dart:io' as io;

import 'package:nexus_studio_server/server_adapter.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

void main() {
  test('ServerAdapter.serve binds and closes', () async {
    final adapter = ServerAdapter();

    final server = await adapter.serve(
      (_) => shelf.Response.ok('ok'),
      io.InternetAddress.loopbackIPv4,
      0,
    );

    await server.close(force: true);
  });
}
