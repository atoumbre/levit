import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:levit_mcp_server/src/tools.dart';

class LevitMcpServer {
  LevitMcpServer({LevitToolRegistry? registry})
      : _registry = registry ?? LevitToolRegistry();

  final LevitToolRegistry _registry;

  Future<void> serve(Stream<List<int>> input, IOSink output) async {
    final parser = _StdioMessageParser();

    await for (final chunk in input) {
      final payloads = parser.push(chunk);
      for (final payload in payloads) {
        await _handlePayload(payload, output);
      }
    }
  }

  Future<void> _handlePayload(String payload, IOSink output) async {
    Map<String, dynamic> request;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      request = decoded;
    } catch (_) {
      return;
    }

    final method = request['method'];
    final id = request['id'];

    if (method is! String) {
      if (id != null) {
        _writeJsonRpc(
          output,
          <String, dynamic>{
            'jsonrpc': '2.0',
            'id': id,
            'error': <String, dynamic>{
              'code': -32600,
              'message': 'Invalid Request',
            },
          },
        );
      }
      return;
    }

    if (method == 'notifications/initialized') {
      return;
    }

    final params = request['params'];
    final paramMap =
        params is Map<String, dynamic> ? params : <String, dynamic>{};

    switch (method) {
      case 'initialize':
        _writeJsonRpc(
          output,
          <String, dynamic>{
            'jsonrpc': '2.0',
            'id': id,
            'result': <String, dynamic>{
              'protocolVersion': '2024-11-05',
              'capabilities': <String, dynamic>{
                'tools': <String, dynamic>{},
                'resources': <String, dynamic>{},
              },
              'serverInfo': <String, String>{
                'name': 'levit_mcp_server',
                'version': '0.1.0',
              },
            },
          },
        );

      case 'ping':
        _writeJsonRpc(
          output,
          <String, dynamic>{
            'jsonrpc': '2.0',
            'id': id,
            'result': <String, dynamic>{},
          },
        );

      case 'tools/list':
        _writeJsonRpc(
          output,
          <String, dynamic>{
            'jsonrpc': '2.0',
            'id': id,
            'result': <String, dynamic>{
              'tools':
                  _registry.listTools().map((tool) => tool.toJson()).toList(),
            },
          },
        );

      case 'tools/call':
        final toolName = paramMap['name'];
        final arguments = paramMap['arguments'];

        if (toolName is! String || arguments is! Map<String, dynamic>) {
          _writeJsonRpc(
            output,
            <String, dynamic>{
              'jsonrpc': '2.0',
              'id': id,
              'error': <String, dynamic>{
                'code': -32602,
                'message': 'Invalid params for tools/call',
              },
            },
          );
          return;
        }

        final toolResult = await _registry.call(toolName, arguments);
        _writeJsonRpc(
          output,
          <String, dynamic>{
            'jsonrpc': '2.0',
            'id': id,
            'result': toolResult.toMcpResult(),
          },
        );

      case 'resources/list':
        _writeJsonRpc(
          output,
          <String, dynamic>{
            'jsonrpc': '2.0',
            'id': id,
            'result': <String, dynamic>{
              'resources': _registry
                  .listResources()
                  .map((resource) => resource.toJson())
                  .toList(growable: false),
            },
          },
        );

      case 'resources/read':
        final uri = paramMap['uri'];
        if (uri is! String || uri.trim().isEmpty) {
          _writeJsonRpc(
            output,
            <String, dynamic>{
              'jsonrpc': '2.0',
              'id': id,
              'error': <String, dynamic>{
                'code': -32602,
                'message': 'Invalid params for resources/read',
              },
            },
          );
          return;
        }

        try {
          final resourceResult = await _registry.readResource(uri);
          _writeJsonRpc(
            output,
            <String, dynamic>{
              'jsonrpc': '2.0',
              'id': id,
              'result': resourceResult,
            },
          );
        } on ArgumentError catch (error) {
          _writeJsonRpc(
            output,
            <String, dynamic>{
              'jsonrpc': '2.0',
              'id': id,
              'error': <String, dynamic>{
                'code': -32602,
                'message': error.message,
              },
            },
          );
        }

      default:
        if (id == null) {
          return;
        }
        _writeJsonRpc(
          output,
          <String, dynamic>{
            'jsonrpc': '2.0',
            'id': id,
            'error': <String, dynamic>{
              'code': -32601,
              'message': 'Method not found: $method',
            },
          },
        );
    }
  }

  void _writeJsonRpc(IOSink output, Map<String, dynamic> message) {
    final body = utf8.encode(jsonEncode(message));
    output
      ..write('Content-Length: ${body.length}\r\n\r\n')
      ..add(body)
      ..flush();
  }
}

class _StdioMessageParser {
  final List<int> _buffer = <int>[];

  List<String> push(List<int> chunk) {
    _buffer.addAll(chunk);
    final messages = <String>[];

    while (true) {
      final headerEnd = _indexOfHeaderEnd(_buffer);
      if (headerEnd < 0) {
        break;
      }

      final headerBytes = _buffer.sublist(0, headerEnd);
      final headerText = ascii.decode(headerBytes, allowInvalid: true);
      final length = _readContentLength(headerText);

      if (length == null) {
        _buffer.clear();
        break;
      }

      final messageStart = headerEnd + 4;
      final messageEnd = messageStart + length;
      if (_buffer.length < messageEnd) {
        break;
      }

      final bodyBytes = _buffer.sublist(messageStart, messageEnd);
      messages.add(utf8.decode(bodyBytes));
      _buffer.removeRange(0, messageEnd);
    }

    return messages;
  }

  int _indexOfHeaderEnd(List<int> data) {
    for (var i = 0; i < data.length - 3; i++) {
      if (data[i] == 13 &&
          data[i + 1] == 10 &&
          data[i + 2] == 13 &&
          data[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  int? _readContentLength(String headerText) {
    final lines = headerText.split('\r\n');
    for (final line in lines) {
      final parts = line.split(':');
      if (parts.length < 2) {
        continue;
      }

      final name = parts.first.trim().toLowerCase();
      if (name != 'content-length') {
        continue;
      }

      return int.tryParse(parts.sublist(1).join(':').trim());
    }

    return null;
  }
}
