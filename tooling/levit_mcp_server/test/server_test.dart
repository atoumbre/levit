import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:levit_mcp_server/levit_mcp_server.dart';
import 'package:test/test.dart';

void main() {
  test('server supports resources/list and resources/read', () async {
    final workspace = await _createWorkspaceFixture();
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    final registry = LevitToolRegistry(workspaceDirectory: workspace);
    final server = LevitMcpServer(registry: registry);

    final input = StreamController<List<int>>();
    final outputController = StreamController<List<int>>();
    final bytes = BytesBuilder();
    final collectOutput = outputController.stream.listen(bytes.add);
    final output = IOSink(outputController.sink);

    final serving = server.serve(input.stream, output);

    _writeRequest(input, <String, dynamic>{
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'resources/list',
      'params': <String, dynamic>{},
    });

    _writeRequest(input, <String, dynamic>{
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'resources/read',
      'params': <String, dynamic>{
        'uri': 'levit://workspace/packages',
      },
    });

    await input.close();
    await serving;
    await output.close();
    await collectOutput.cancel();
    await outputController.close();

    final responses = _parseResponses(bytes.takeBytes());
    expect(responses.length, 2);
    expect(
      responses.first['result']['resources'][0]['uri'],
      'levit://workspace/packages',
    );

    final contents = responses.last['result']['contents'] as List<dynamic>;
    expect(contents.single['uri'], 'levit://workspace/packages');
  });
}

Future<Directory> _createWorkspaceFixture() async {
  final root =
      await Directory.systemTemp.createTemp('levit_mcp_server_fixture_');
  final pubspec = File('${root.path}/packages/core/alpha_core/pubspec.yaml');
  await pubspec.parent.create(recursive: true);
  await pubspec.writeAsString('name: alpha_core\n');
  return root;
}

void _writeRequest(
  StreamController<List<int>> input,
  Map<String, dynamic> payload,
) {
  final body = utf8.encode(jsonEncode(payload));
  final header = ascii.encode('Content-Length: ${body.length}\r\n\r\n');
  input.add(<int>[...header, ...body]);
}

List<Map<String, dynamic>> _parseResponses(List<int> raw) {
  final responses = <Map<String, dynamic>>[];
  var offset = 0;

  while (offset < raw.length) {
    final headerEnd = _indexOfSequence(raw, <int>[13, 10, 13, 10], offset);
    if (headerEnd < 0) {
      break;
    }
    final header = ascii.decode(raw.sublist(offset, headerEnd));
    final length = _contentLength(header);
    final bodyStart = headerEnd + 4;
    final bodyEnd = bodyStart + length;
    final payload = utf8.decode(raw.sublist(bodyStart, bodyEnd));
    responses.add(jsonDecode(payload) as Map<String, dynamic>);
    offset = bodyEnd;
  }

  return responses;
}

int _indexOfSequence(List<int> data, List<int> target, int start) {
  for (var i = start; i <= data.length - target.length; i++) {
    var ok = true;
    for (var j = 0; j < target.length; j++) {
      if (data[i + j] != target[j]) {
        ok = false;
        break;
      }
    }
    if (ok) {
      return i;
    }
  }
  return -1;
}

int _contentLength(String header) {
  final line = header
      .split('\r\n')
      .firstWhere((entry) => entry.toLowerCase().startsWith('content-length:'));
  return int.parse(line.split(':').last.trim());
}
