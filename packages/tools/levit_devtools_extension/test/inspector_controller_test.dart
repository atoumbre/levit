import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:levit_devtools_extension/src/client/devtools_client.dart';
import 'package:levit_devtools_extension/src/controller/inspector_controller.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_monitor/spi.dart';

class FakeDevToolsClient implements LevitDevToolsClient {
  LevitRemoteSnapshotResult snapshotResult;
  List<LevitEventEnvelope> history;
  final StreamController<LevitEventEnvelope> eventStream =
      StreamController<LevitEventEnvelope>.broadcast();
  final StreamController<bool> connectionStream =
      StreamController<bool>.broadcast();
  bool disposed = false;

  FakeDevToolsClient({required this.snapshotResult, this.history = const []});

  @override
  Future<LevitRemoteSnapshotResult> fetchSnapshot() async => snapshotResult;

  @override
  Future<List<LevitEventEnvelope>> fetchHistory({int limit = 500}) async =>
      history;

  @override
  Stream<LevitEventEnvelope> get events => eventStream.stream;

  @override
  Stream<bool> get connectionChanges => connectionStream.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    await eventStream.close();
    await connectionStream.close();
  }
}

void main() {
  setUpAll(Levit.enableAutoLinking);

  group('LevitInspectorController', () {
    test(
      'hydrates snapshot, applies live events, and buffers while paused',
      () async {
        final client = FakeDevToolsClient(
          snapshotResult: LevitRemoteSnapshotResult(
            attached: true,
            snapshot: {
              'scopes': [
                {
                  'id': 1,
                  'name': 'root',
                  'parentScopeId': null,
                  'progress': {},
                },
              ],
              'dependencies': [
                {
                  'scopeId': 1,
                  'key': 'CounterController',
                  'isLazy': false,
                  'isFactory': false,
                  'isAsync': false,
                  'status': 'active',
                  'type': 'controller',
                  'value': 'CounterController',
                },
              ],
              'variables': [
                {
                  'id': 100,
                  'name': 'count',
                  'ownerId': '1:CounterController',
                  'isSensitive': false,
                  'value': '1',
                  'valueType': 'int',
                  'dependencies': <int>[],
                  'listenerCount': 2,
                },
                {
                  'id': 101,
                  'name': 'orphan',
                  'ownerId': null,
                  'isSensitive': true,
                  'value': '***',
                  'valueType': 'String',
                  'dependencies': <int>[],
                  'listenerCount': 1,
                },
              ],
              'taskTrees': <String, dynamic>{},
            },
          ),
        );

        final scope = Levit.createScope('test_devtools');
        final controller = scope.put(() => LevitInspectorController(client));
        await Future<void>.delayed(Duration.zero);

        expect(controller.attached.value, isTrue);
        expect(controller.snapshot.scopes.length, 1);
        expect(controller.snapshot.variables.length, 2);
        expect(
          controller.findings.map((f) => f.code),
          contains('unowned_reactives'),
        );

        // Pause stream and emit a live state change; it stays buffered until resumed.
        controller.togglePause();
        expect(controller.paused.value, isTrue);

        client.eventStream.add(
          LevitEventEnvelope.stateChange(
            sessionId: 's1',
            seq: 5,
            timestamp: '2026-11-26T00:00:05Z',
            reactiveId: '100',
            name: 'count',
            ownerId: '1:CounterController',
            isSensitive: false,
            oldValue: '1',
            newValue: '42',
            valueType: 'int',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(controller.pausedCount.value, 1);
        expect(controller.snapshot.variables[100]!.value, '1');

        // Resume flushes buffered event.
        controller.togglePause();
        expect(controller.paused.value, isFalse);
        expect(controller.pausedCount.value, 0);
        expect(controller.snapshot.variables[100]!.value, '42');
        expect(controller.filteredTimeline.length, 1);

        // Filters work cleanly.
        controller.reactiveFilter.value = ReactiveFilterMode.sensitive;
        expect(controller.filteredReactives.map((v) => v.name), ['orphan']);

        // Export contains redacted snapshot JSON.
        final exported = controller.exportRedactedJson();
        expect(exported, contains('CounterController'));
        expect(exported, contains('unowned_reactives'));

        // Clear local timeline empties events while retaining scopes/variables.
        controller.clearLocalTimeline();
        expect(controller.filteredTimeline, isEmpty);
        expect(controller.snapshot.scopes.length, 1);

        await scope.dispose();
        expect(client.disposed, isTrue);
      },
    );
  });
}
