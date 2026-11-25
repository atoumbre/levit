import 'dart:convert';
import 'dart:io';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor_io.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

void main() {
  group('LevitFileTransport', () {
    late Directory tempDir;
    late String filePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_transport_test');
      filePath = '${tempDir.path}/log.jsonl';
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('writes LevitDependencyRegisterEvent to file with category', () async {
      final transport = LevitFileTransport(filePath);
      final info = LevitDependency(builder: () => 42);
      final event = LevitDependencyRegisterEvent(
        sessionId: 's1',
        scopeId: 1,
        scopeName: 'root',
        key: 'Service',
        info: info,
        source: 'test',
      );

      transport.send(event);
      await Future.delayed(Duration(milliseconds: 100)); // Allow flush
      await transport.close();

      final file = File(filePath);
      expect(file.existsSync(), isTrue);
      final lines = await file.readAsLines();
      expect(lines, hasLength(1));

      final json = jsonDecode(lines.first);
      expect(json['category'], 'di');
      expect(json['type'], 'di_register');
      expect(json['scopeName'], 'root');
    });

    test('writes LevitReactiveChangeEvent to file with category', () async {
      final transport = LevitFileTransport(filePath);
      final reactive = 10.lx.named('rx');
      final change = LevitReactiveChange(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 10,
        newValue: 11,
      );
      final event = LevitReactiveChangeEvent(
        sessionId: 's1',
        reactive: reactive,
        change: change,
      );

      transport.send(event);
      await Future.delayed(Duration(milliseconds: 100)); // Allow flush
      await transport.close();

      final file = File(filePath);
      expect(file.existsSync(), isTrue);
      final lines = await file.readAsLines();
      expect(lines, hasLength(1));

      final json = jsonDecode(lines.first);
      expect(json['category'], 'state');
      expect(json['type'], 'state_change');
      expect(json['newValue'], '11');
    });

    test('writes LevitLogEvent to file with correct category', () async {
      final transport = LevitFileTransport(filePath);
      final event = LevitLogEvent(
        sessionId: 's1',
        level: LevitLogLevel.info,
        data: 'test log',
      );

      transport.send(event);
      await Future.delayed(Duration(milliseconds: 100)); // Allow flush
      await transport.close();

      final file = File(filePath);
      expect(file.existsSync(), isTrue);
      final lines = await file.readAsLines();
      expect(lines, hasLength(1));

      final json = jsonDecode(lines.first);
      expect(json['category'], 'log');
      expect(json['type'], 'log');
      expect(json['level'], 'info');
      expect(json['data'], 'test log');
    });

    test('close releases resources', () async {
      final transport = LevitFileTransport(filePath);
      await transport.close();
    });

    test(
      'failed IO is reported after idempotent close attempts cleanup',
      () async {
        final transport = LevitFileTransport(
          tempDir.path,
        ); // A directory cannot be opened as a file.
        transport.send(
          LevitLogEvent(
            sessionId: 'io',
            level: LevitLogLevel.info,
            data: 'write',
          ),
        );
        await expectLater(
          transport.flush(),
          throwsA(isA<LevitMonitorException>()),
        );
        final closing = transport.close();
        expect(identical(closing, transport.close()), isTrue);
        await expectLater(closing, throwsA(isA<LevitMonitorException>()));
        expect(
          () => transport.send(
            LevitLogEvent(
              sessionId: 'io',
              level: LevitLogLevel.info,
              data: 'late',
            ),
          ),
          throwsStateError,
        );
      },
    );
  });
}
