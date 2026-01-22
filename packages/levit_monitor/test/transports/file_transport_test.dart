import 'dart:convert';
import 'dart:io';

import 'package:levit_dart/levit_dart.dart';
import 'package:levit_monitor/src/core/event.dart';
import 'package:levit_monitor/src/transports/file_transport.dart';
import 'package:test/test.dart';

void main() {
  group('FileTransport', () {
    late Directory tempDir;
    late String filePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_transport_test');
      filePath = '${tempDir.path}/log.jsonl';
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('writes DependencyRegisterEvent to file with category', () async {
      final transport = FileTransport(filePath);
      final info = LevitDependency(builder: () => 42);
      final event = DependencyRegisterEvent(
        sessionId: 's1',
        scopeId: 1,
        scopeName: 'root',
        key: 'Service',
        info: info,
        source: 'test',
      );

      transport.send(event);
      await Future.delayed(Duration(milliseconds: 100)); // Allow flush
      transport.close();

      final file = File(filePath);
      expect(file.existsSync(), isTrue);
      final lines = await file.readAsLines();
      expect(lines, hasLength(1));

      final json = jsonDecode(lines.first);
      expect(json['category'], 'di');
      expect(json['type'], 'di_register');
      expect(json['scopeName'], 'root');
    });

    test('writes ReactiveChangeEvent to file with category', () async {
      final transport = FileTransport(filePath);
      final reactive = 10.lx.named('rx');
      final change = LevitReactiveChange(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 10,
        newValue: 11,
      );
      final event = ReactiveChangeEvent(
        sessionId: 's1',
        reactive: reactive,
        change: change,
      );

      transport.send(event);
      await Future.delayed(Duration(milliseconds: 100)); // Allow flush
      transport.close();

      final file = File(filePath);
      expect(file.existsSync(), isTrue);
      final lines = await file.readAsLines();
      expect(lines, hasLength(1));

      final json = jsonDecode(lines.first);
      expect(json['category'], 'state');
      expect(json['type'], 'state_change');
      expect(json['newValue'], '11');
    });

    test('close releases resources', () async {
      final transport = FileTransport(filePath);
      transport.close();
    });
  });
}
