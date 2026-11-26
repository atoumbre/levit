import 'dart:convert';

import 'package:dart_mcp/client.dart';
import 'package:levit_mcp/levit_mcp.dart';
import 'package:levit_monitor/spi.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

Map<String, dynamic> _decodeToolJson(CallToolResult result) {
  expect(result.isError, isNot(true));
  final text = (result.content.first as TextContent).text;
  return Map<String, dynamic>.from(jsonDecode(text) as Map);
}

void main() {
  group('LevitMcpProtocolServer tools and resources', () {
    late LevitSessionStore store;
    late StreamChannelController<String> pipe;
    late LevitMcpProtocolServer server;
    late MCPClient client;
    late ServerConnection connection;

    setUp(() async {
      store = LevitSessionStore(historyCapacity: 50);
      pipe = StreamChannelController<String>();
      server = LevitMcpProtocolServer(pipe.local, store: store);
      client = MCPClient(Implementation(name: 'test-client', version: '1.0.0'));
      connection = client.connectServer(pipe.foreign);
      await connection.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: client.capabilities,
          clientInfo: client.implementation,
        ),
      );
      connection.notifyInitialized();
      await server.initialized;
    });

    tearDown(() async {
      await client.shutdown();
      await server.shutdown();
    });

    test(
      'advertises all 6 read-only tools and reports error when no sessions exist',
      () async {
        final toolsResult = await connection.listTools();
        final names = toolsResult.tools.map((t) => t.name).toSet();
        expect(
          names,
          equals({
            'list_sessions',
            'inspect_scope_tree',
            'inspect_reactive_graph',
            'query_timeline',
            'inspect_task_tree',
            'diagnose_runtime',
          }),
        );

        final emptySessions = _decodeToolJson(
          await connection.callTool(CallToolRequest(name: 'list_sessions')),
        );
        expect(emptySessions['total'], 0);

        for (final toolName in const [
          'inspect_scope_tree',
          'inspect_reactive_graph',
          'query_timeline',
          'inspect_task_tree',
          'diagnose_runtime',
        ]) {
          final res = await connection.callTool(
            CallToolRequest(name: toolName),
          );
          expect(res.isError, isTrue);
        }
      },
    );

    test(
      'queries scopes, reactive graph, timeline, task trees, diagnostics, and resources',
      () async {
        store.applyEnvelope(
          'app-session',
          LevitEventEnvelope({
            'seq': 1,
            'category': 'di',
            'type': 'scope_create',
            'scopeId': 1,
            'scopeName': 'root',
          }),
          appId: 'nexus',
        );
        store.applyEnvelope(
          'app-session',
          LevitEventEnvelope({
            'seq': 2,
            'category': 'di',
            'type': 'scope_create',
            'scopeId': 2,
            'scopeName': 'feature',
            'parentScopeId': 1,
          }),
        );
        store.applyEnvelope(
          'app-session',
          LevitEventEnvelope({
            'seq': 3,
            'category': 'di',
            'type': 'di_register',
            'scopeId': 2,
            'scopeName': 'feature',
            'key': 'CounterController',
            'isLazy': false,
            'isFactory': false,
            'isAsync': false,
          }),
        );
        store.applyEnvelope(
          'app-session',
          LevitEventEnvelope({
            'seq': 4,
            'category': 'state',
            'type': 'reactive_init',
            'reactiveId': 10,
            'name': 'count',
            'ownerId': '2:CounterController',
            'initialValue': 1,
            'valueType': 'int',
          }),
        );
        store.applyEnvelope(
          'app-session',
          LevitEventEnvelope({
            'seq': 5,
            'category': 'state',
            'type': 'reactive_init',
            'reactiveId': 11,
            'name': 'doubledCount',
            'ownerId': '2:CounterController',
            'initialValue': 2,
            'valueType': 'int',
          }),
        );
        store.applyEnvelope(
          'app-session',
          LevitEventEnvelope({
            'seq': 6,
            'category': 'state',
            'type': 'graph_change',
            'reactiveId': 11,
            'dependencies': [
              {'id': 10},
            ],
          }),
        );
        store.applyEnvelope(
          'app-session',
          LevitEventEnvelope({
            'seq': 7,
            'category': 'state',
            'type': 'reactive_init',
            'reactiveId': 12,
            'name': 'dangling',
            'initialValue': 'orphan',
          }),
        );
        store.applyEnvelope(
          'app-session',
          LevitEventEnvelope({
            'seq': 8,
            'category': 'custom',
            'type': 'custom',
            'namespace': 'levit.tasks',
            'name': 'tree',
            'attributes': {
              'ownerPath': '2:CounterController',
              'nodes': [
                {
                  'id': 'root-group',
                  'children': [
                    {
                      'id': 'leaf-1',
                      'nested': {'deep': true},
                    },
                  ],
                },
              ],
            },
          }),
        );

        // inspect_scope_tree (full tree + subtree + missing subtree)
        final fullTree = _decodeToolJson(
          await connection.callTool(
            CallToolRequest(name: 'inspect_scope_tree'),
          ),
        );
        expect(fullTree['scopeCount'], 2);
        final roots = fullTree['roots'] as List;
        expect((roots.first as Map)['name'], 'root');
        expect(((roots.first as Map)['children'] as List).length, 1);

        final subTree = _decodeToolJson(
          await connection.callTool(
            CallToolRequest(
              name: 'inspect_scope_tree',
              arguments: {'rootScopeId': 2, 'includeRegistrations': false},
            ),
          ),
        );
        expect(((subTree['roots'] as List).first as Map)['id'], 2);

        final missingScope = await connection.callTool(
          CallToolRequest(
            name: 'inspect_scope_tree',
            arguments: {'rootScopeId': 999},
          ),
        );
        expect(missingScope.isError, isTrue);

        // inspect_reactive_graph filters & edges
        final allVars = _decodeToolJson(
          await connection.callTool(
            CallToolRequest(
              name: 'inspect_reactive_graph',
              arguments: {'limit': 2},
            ),
          ),
        );
        expect(allVars['totalMatched'], 3);
        expect(allVars['truncated'], isTrue);
        expect((allVars['edges'] as List).first, {'from': 10, 'to': 11});

        final byOwner = _decodeToolJson(
          await connection.callTool(
            CallToolRequest(
              name: 'inspect_reactive_graph',
              arguments: {
                'ownerId': '2:CounterController',
                'scopeId': 2,
                'nameContains': 'doubled',
              },
            ),
          ),
        );
        expect(byOwner['totalMatched'], 1);

        final orphans = _decodeToolJson(
          await connection.callTool(
            CallToolRequest(
              name: 'inspect_reactive_graph',
              arguments: {'orphansOnly': true},
            ),
          ),
        );
        expect(orphans['totalMatched'], 1);

        // query_timeline filters + limit slice
        final timeline = _decodeToolJson(
          await connection.callTool(
            CallToolRequest(
              name: 'query_timeline',
              arguments: {
                'category': 'state',
                'type': 'reactive_init',
                'reactiveId': 11,
                'sinceSeq': 4,
                'limit': 1,
              },
            ),
          ),
        );
        expect(timeline['returned'], 1);

        final scopeTimeline = _decodeToolJson(
          await connection.callTool(
            CallToolRequest(
              name: 'query_timeline',
              arguments: {'scopeId': 2, 'limit': 1},
            ),
          ),
        );
        expect(scopeTimeline['returned'], 1);

        // inspect_task_tree (all, exact ownerPath, bounded depth, missing owner)
        final allTasks = _decodeToolJson(
          await connection.callTool(
            CallToolRequest(
              name: 'inspect_task_tree',
              arguments: {'maxDepth': 2},
            ),
          ),
        );
        expect(allTasks['count'], 1);

        final ownerTask = _decodeToolJson(
          await connection.callTool(
            CallToolRequest(
              name: 'inspect_task_tree',
              arguments: {'ownerPath': '2:CounterController', 'maxDepth': 1},
            ),
          ),
        );
        final bounded =
            (ownerTask['taskTrees'] as Map)['2:CounterController'] as Map;
        expect(bounded['nodes'], ['<truncated>']);

        final missingTask = await connection.callTool(
          CallToolRequest(
            name: 'inspect_task_tree',
            arguments: {'ownerPath': 'missing'},
          ),
        );
        expect(missingTask.isError, isTrue);

        // diagnose_runtime flags the dangling unowned reactive
        final diag = _decodeToolJson(
          await connection.callTool(CallToolRequest(name: 'diagnose_runtime')),
        );
        expect(diag['healthy'], isFalse);
        expect(diag['findingCount'], 1);

        // Resources: levit://sessions and levit://sessions/{id}/snapshot
        final resources = await connection.listResources();
        expect(
          resources.resources.map((r) => r.uri),
          contains('levit://sessions'),
        );

        final sessionsRes = await connection.readResource(
          ReadResourceRequest(uri: 'levit://sessions'),
        );
        final sessionsJson =
            jsonDecode(
                  (sessionsRes.contents.first as TextResourceContents).text,
                )
                as Map;
        expect((sessionsJson['sessions'] as List).length, 1);

        final templates = await connection.listResourceTemplates();
        expect(
          templates.resourceTemplates.map((t) => t.uriTemplate),
          contains('levit://sessions/{sessionId}/snapshot'),
        );

        final snapRes = await connection.readResource(
          ReadResourceRequest(uri: 'levit://sessions/app-session/snapshot'),
        );
        final snapJson =
            jsonDecode((snapRes.contents.first as TextResourceContents).text)
                as Map;
        expect((snapJson['session'] as Map)['sessionId'], 'app-session');

        // Unknown resource URIs trigger RPC error cleanly.
        await expectLater(
          connection.readResource(
            ReadResourceRequest(uri: 'levit://sessions/unknown/snapshot'),
          ),
          throwsA(anything),
        );
        await expectLater(
          connection.readResource(
            ReadResourceRequest(uri: 'levit://sessions//snapshot'),
          ),
          throwsA(anything),
        );
        await expectLater(
          connection.readResource(ReadResourceRequest(uri: 'levit://other')),
          throwsA(anything),
        );
      },
    );
  });
}
