import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_devtools_ui/main.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  testWidgets(
    'renders sessions, ownership, cleanup, task trees and update details',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final incoming = StreamController<dynamic>();
      final outgoing = StreamController<dynamic>();
      final channel = _Channel(incoming, outgoing);
      final sent = <Map<String, dynamic>>[];
      final subscription = outgoing.stream.listen(
        (raw) => sent.add(
          Map<String, dynamic>.from(jsonDecode(raw as String) as Map),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: InspectorScreen(channelFactory: (_) => channel)),
      );
      incoming.add(
        jsonEncode({
          'kind': 'sessions',
          'delivery': 1,
          'sessions': [
            {'id': 'app', 'appId': 'nexus-studio', 'connected': true},
            {'id': 'server', 'appId': 'nexus-server', 'connected': true},
          ],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('nexus-studio'), findsWidgets);
      incoming.add(
        jsonEncode({
          'kind': 'snapshot',
          'delivery': 2,
          'session': {'id': 'app'},
          'state': {
            'scopes': [
              {
                'id': 1,
                'name': 'project',
                'progress': {'isClosing': true, 'pendingInitializations': 1},
              },
            ],
            'dependencies': [],
            'variables': [
              {
                'id': 3,
                'name': 'count',
                'ownerId': '1:Controller',
                'value': '2',
                'valueType': 'int',
                'listenerCount': 1,
                'dependencies': [],
              },
            ],
            'taskTrees': {
              '1:Controller': {
                'tree': {
                  'id': 'g1',
                  'name': 'upload',
                  'pendingCount': 1,
                  'runningCount': 2,
                  'executionIds': ['task1'],
                  'children': [],
                },
              },
            },
          },
          'timeline': [
            {
              'seq': 4,
              'type': 'state_change',
              'category': 'state',
              'name': 'count',
              'oldValue': '1',
              'newValue': '2',
              'ownerId': '1:Controller',
              'timestamp': 'now',
            },
          ],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('project #1'), findsOneWidget);
      await tester.tap(find.text('Cleanup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('pendingInitializations'), findsOneWidget);
      incoming.add(
        jsonEncode({
          'kind': 'event',
          'delivery': 3,
          'session': {'id': 'app'},
          'event': {
            'sessionId': 'app',
            'seq': 5,
            'timestamp': '2026-11-11T00:00:00Z',
            'type': 'scope_progress',
            'category': 'di',
            'version': 1,
            'scope': [
              1,
              'project',
              1,
              2,
              [],
              [],
              [
                ['Repo', 'Repo', null, 48, 2, 1],
              ],
            ],
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('"pendingInitializations": 2'),
        findsOneWidget,
      );
      expect(find.textContaining('"isClosing": true'), findsOneWidget);
      incoming.add(
        jsonEncode({
          'kind': 'event',
          'delivery': 4,
          'session': {'id': 'app'},
          'event': {
            'sessionId': 'app',
            'seq': 6,
            'timestamp': '2026-11-11T00:00:00Z',
            'type': 'scope_dispose',
            'category': 'di',
            'scopeId': 1,
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('pendingInitializations'), findsNothing);
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.textContaining('upload'), findsOneWidget);
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('#4 state_change'));
      await tester.pumpAndSettle();
      expect(find.text('Update details'), findsOneWidget);
      expect(find.textContaining('"newValue": "2"'), findsOneWidget);
      expect(sent.any((message) => message['select'] == 'app'), isTrue);
      expect(sent.any((message) => message['ack'] == 2), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await subscription.cancel();
        await incoming.close();
        await outgoing.close();
      });
    },
  );
}

class _Channel implements WebSocketChannel {
  final StreamController<dynamic> incoming;
  final StreamController<dynamic> outgoing;
  _Channel(this.incoming, this.outgoing);
  @override
  Stream<dynamic> get stream => incoming.stream;
  @override
  WebSocketSink get sink => _Sink(outgoing);
  @override
  Future<void> get ready => Future.value();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sink implements WebSocketSink {
  final StreamController<dynamic> output;
  _Sink(this.output);
  @override
  void add(dynamic value) => output.add(value);
  @override
  Future<void> close([int? code, String? reason]) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
