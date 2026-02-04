import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

class MockTransport implements LevitTransport {
  final List<MonitorEvent> events = [];

  @override
  void send(MonitorEvent event) {
    events.add(event);
  }

  @override
  Future<void> close() async {}

  @override
  Stream<void> get onConnect => const Stream.empty();
}

void main() {
  group('Sensitive Data Protection', () {
    late MockTransport transport;

    setUp(() {
      transport = MockTransport();
      LevitMonitor.attach(transport: transport);
      LevitMonitor.setObfuscator(null); // Reset to default
    });

    tearDown(() {
      LevitMonitor.detach();
      Levit.reset(force: true);
    });

    test('default obfuscation masks sensitive data with ***', () async {
      final password =
          'my-secret-password'.lxVar(named: 'password', isSensitive: true);

      // Allow events to reach transport
      await Future.delayed(const Duration(milliseconds: 10));

      final initEvent = transport.events
          .firstWhere((e) => e is ReactiveInitEvent) as ReactiveInitEvent;
      expect(initEvent.toJson()['initialValue'], '***');
      expect(initEvent.toJson()['isSensitive'], true);

      password.value = 'new-password';

      // Allow events to reach transport
      await Future.delayed(const Duration(milliseconds: 10));

      final changeEvent = transport.events
          .firstWhere((e) => e is ReactiveChangeEvent) as ReactiveChangeEvent;
      expect(changeEvent.toJson()['oldValue'], '***');
      expect(changeEvent.toJson()['newValue'], '***');
    });

    test('custom obfuscator is respected', () async {
      LevitMonitor.setObfuscator((value) => 'HIDDEN(${value.length})');

      'abc-123'.lxVar(named: 'token', isSensitive: true);

      await Future.delayed(const Duration(milliseconds: 10));

      final initEvent = transport.events
          .firstWhere((e) => e is ReactiveInitEvent) as ReactiveInitEvent;
      expect(initEvent.toJson()['initialValue'], 'HIDDEN(7)');
    });

    test('non-sensitive data is not obfuscated', () async {
      final count = 0.lxVar(named: 'count');

      await Future.delayed(const Duration(milliseconds: 10));

      final initEvent = transport.events
          .firstWhere((e) => e is ReactiveInitEvent) as ReactiveInitEvent;
      expect(initEvent.toJson()['initialValue'], '0');
      expect(initEvent.toJson()['isSensitive'], false);

      count.value = 1;

      await Future.delayed(const Duration(milliseconds: 10));

      final changeEvent = transport.events
          .firstWhere((e) => e is ReactiveChangeEvent) as ReactiveChangeEvent;
      expect(changeEvent.toJson()['newValue'], '1');
    });

    test('batch updates respect sensitivity per variable', () async {
      final sensitive = 'secret'.lxVar(named: 'sensitive', isSensitive: true);
      final normal = 'public'.lxVar(named: 'normal');

      Levit.batch(() {
        sensitive.value = 'new-secret';
        normal.value = 'new-public';
      });

      await Future.delayed(const Duration(milliseconds: 10));

      final batchEvent = transport.events
          .firstWhere((e) => e is ReactiveBatchEvent) as ReactiveBatchEvent;
      final entries = batchEvent.toJson()['entries'] as List;

      final sEntry = entries.firstWhere((e) =>
          e['name'] == 'sensitive' ||
          e['reactiveId'] == sensitive.id.toString());
      final nEntry = entries.firstWhere((e) =>
          e['name'] == 'normal' || e['reactiveId'] == normal.id.toString());

      expect(sEntry['newValue'], '***');
      expect(nEntry['newValue'], 'new-public');
    });

    test('StateSnapshot stores obfuscated values for sensitive variables',
        () async {
      final secret = 'ssh'.lxVar(isSensitive: true);
      secret.value = 'updated-ssh';

      // Allow events to reach transport
      await Future.delayed(const Duration(milliseconds: 10));

      final stateSnapshot = StateSnapshot();
      for (final event in transport.events) {
        stateSnapshot.applyEvent(event);
      }

      final reactiveModel = stateSnapshot.variables[secret.id];
      expect(reactiveModel?.value, '***');
      expect(reactiveModel?.isSensitive, true);
    });
  });
}
