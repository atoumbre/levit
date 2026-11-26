/// @docImport 'package:stream_channel/stream_channel.dart';
library;

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:levit_monitor/spi.dart';

import 'diagnostics.dart';
import 'session_store.dart';

/// MCP protocol server exposing read-only Levit runtime inspection tools and
/// session snapshot resources over a [StreamChannel].
///
/// Registers six read-only MCP tools:
/// - `list_sessions`: Active and recently disconnected sessions.
/// - `inspect_scope_tree`: Live DI scope hierarchy, registrations, and cleanup
///   state.
/// - `inspect_reactive_graph`: Redacted reactive variables, `LxComputed`
///   dependency edges, and listener counts.
/// - `query_timeline`: Filtered bounded event history with drop accounting.
/// - `inspect_task_tree`: Structured task trees emitted via `levit.tasks/tree`
///   custom events (depth-capped by [maxTaskTreeDepth]).
/// - `diagnose_runtime`: Deterministic anomaly report via
///   [LevitRuntimeDiagnostics.analyze].
///
/// Also exposes two MCP resources:
/// - `levit://sessions`: JSON list of session summaries.
/// - `levit://sessions/{sessionId}/snapshot`: Full JSON snapshot for a session.
///
/// {@category MCP Protocol}
final class LevitMcpProtocolServer extends MCPServer
    with ToolsSupport, ResourcesSupport {
  /// Session store queried by all tools and resources.
  final LevitSessionStore store;

  /// Maximum depth allowed when projecting task trees.
  final int maxTaskTreeDepth;

  static const _readOnlyAnnotations = {
    'readOnlyHint': true,
    'destructiveHint': false,
    'idempotentHint': true,
    'openWorldHint': false,
  };

  /// Creates an MCP protocol server bound to [channel] and [store].
  ///
  /// - [channel]: Line-delimited JSON-RPC transport (for example `stdioChannel`).
  /// - [store]: Multi-session telemetry store backing all tool and resource
  ///   queries.
  /// - [maxTaskTreeDepth]: Maximum recursion depth returned by
  ///   `inspect_task_tree` (defaults to `16`).
  /// - [version]: Server implementation version advertised during the MCP
  ///   handshake (defaults to `'0.1.0'`).
  LevitMcpProtocolServer(
    super.channel, {
    required this.store,
    this.maxTaskTreeDepth = 16,
    String version = '0.1.0',
  }) : super.fromStreamChannel(
         implementation: Implementation(name: 'levit_mcp', version: version),
         instructions:
             'Read-only live runtime inspector for Levit Dart/Flutter apps. '
             'Start with list_sessions, then inspect scopes, reactive graphs, '
             'timelines, task trees, or run diagnose_runtime.',
       ) {
    _registerTools();
    _registerResources();
  }

  void _registerTools() {
    final annotations = ToolAnnotations.fromMap(_readOnlyAnnotations);

    registerTool(
      Tool(
        name: 'list_sessions',
        description:
            'List connected and recently disconnected Levit runtime sessions '
            'with counts of scopes, dependencies, reactives, tasks, and errors.',
        inputSchema: Schema.object(),
        annotations: annotations,
      ),
      _handleListSessions,
    );

    registerTool(
      Tool(
        name: 'inspect_scope_tree',
        description:
            'Inspect the live Levit DI scope hierarchy, registrations, '
            'lifecycle flags, and pending initializations.',
        inputSchema: Schema.object(
          properties: {
            'sessionId': Schema.string(
              description:
                  'Target session ID (optional when only one session exists).',
            ),
            'rootScopeId': Schema.int(
              description: 'Optional scope ID to use as the subtree root.',
            ),
            'includeRegistrations': Schema.bool(
              description:
                  'Include registered dependencies per scope (default: true).',
            ),
          },
        ),
        annotations: annotations,
      ),
      _handleInspectScopeTree,
    );

    registerTool(
      Tool(
        name: 'inspect_reactive_graph',
        description:
            'Inspect redacted reactive variables, LxComputed dependency edges, '
            'ownership metadata, and active listener counts.',
        inputSchema: Schema.object(
          properties: {
            'sessionId': Schema.string(
              description:
                  'Target session ID (optional when only one session exists).',
            ),
            'ownerId': Schema.string(
              description: 'Filter to reactives matching exact ownerId.',
            ),
            'scopeId': Schema.int(
              description: 'Filter to reactives owned by a specific scope ID.',
            ),
            'nameContains': Schema.string(
              description:
                  'Case-insensitive substring filter on reactive name.',
            ),
            'orphansOnly': Schema.bool(
              description:
                  'Return only unowned reactives (missing or "?" ownerId).',
            ),
            'limit': Schema.int(
              description:
                  'Maximum variables returned (default: 100, max: 500).',
              minimum: 1,
              maximum: 500,
            ),
          },
        ),
        annotations: annotations,
      ),
      _handleInspectReactiveGraph,
    );

    registerTool(
      Tool(
        name: 'query_timeline',
        description:
            'Query bounded historical LevitMonitor events for a session with '
            'optional category, type, scope, reactive, and sequence filters.',
        inputSchema: Schema.object(
          properties: {
            'sessionId': Schema.string(
              description:
                  'Target session ID (optional when only one session exists).',
            ),
            'category': Schema.string(
              description:
                  'Event category filter (e.g. di, state, log, custom).',
            ),
            'type': Schema.string(
              description:
                  'Exact event type filter (e.g. state_change, scope_create).',
            ),
            'scopeId': Schema.int(
              description: 'Filter events matching data.scopeId.',
            ),
            'reactiveId': Schema.int(
              description: 'Filter events matching data.reactiveId.',
            ),
            'sinceSeq': Schema.int(
              description: 'Return only events with seq > sinceSeq.',
            ),
            'limit': Schema.int(
              description: 'Maximum events returned (default: 50, max: 200).',
              minimum: 1,
              maximum: 200,
            ),
          },
        ),
        annotations: annotations,
      ),
      _handleQueryTimeline,
    );

    registerTool(
      Tool(
        name: 'inspect_task_tree',
        description:
            'Inspect structured task trees reported via levit.tasks/tree '
            'custom monitor events.',
        inputSchema: Schema.object(
          properties: {
            'sessionId': Schema.string(
              description:
                  'Target session ID (optional when only one session exists).',
            ),
            'ownerPath': Schema.string(
              description: 'Optional exact ownerPath filter.',
            ),
            'maxDepth': Schema.int(
              description: 'Maximum nesting depth to include (default: 8).',
              minimum: 1,
              maximum: 16,
            ),
          },
        ),
        annotations: annotations,
      ),
      _handleInspectTaskTree,
    );

    registerTool(
      Tool(
        name: 'diagnose_runtime',
        description:
            'Run deterministic runtime diagnostics on a Levit session to flag '
            'unowned reactives, closing scopes, pending initializations, high '
            'listener counts, recent errors, and dropped telemetry.',
        inputSchema: Schema.object(
          properties: {
            'sessionId': Schema.string(
              description:
                  'Target session ID (optional when only one session exists).',
            ),
            'highListenerThreshold': Schema.int(
              description:
                  'Listener count threshold for warnings (default: 50).',
              minimum: 1,
            ),
          },
        ),
        annotations: annotations,
      ),
      _handleDiagnoseRuntime,
    );
  }

  void _registerResources() {
    addResource(
      Resource(
        uri: 'levit://sessions',
        name: 'sessions',
        description: 'Summary index of connected and recent Levit sessions.',
        mimeType: 'application/json',
      ),
      (request) => ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: request.uri,
            mimeType: 'application/json',
            text: _encodeJson({
              'sessions': store.sessions.map((s) => s.toSummaryJson()).toList(),
            }),
          ),
        ],
      ),
    );

    addResourceTemplate(
      ResourceTemplate(
        uriTemplate: 'levit://sessions/{sessionId}/snapshot',
        name: 'session_snapshot',
        description: 'Current redacted LevitStateSnapshot for a session.',
        mimeType: 'application/json',
      ),
      (request) {
        const prefix = 'levit://sessions/';
        const suffix = '/snapshot';
        if (!request.uri.startsWith(prefix) || !request.uri.endsWith(suffix)) {
          return null;
        }
        final encodedId = request.uri.substring(
          prefix.length,
          request.uri.length - suffix.length,
        );
        if (encodedId.isEmpty) return null;
        final sessionId = Uri.decodeComponent(encodedId);
        final session = store[sessionId];
        if (session == null) return null;
        return ReadResourceResult(
          contents: [
            TextResourceContents(
              uri: request.uri,
              mimeType: 'application/json',
              text: _encodeJson({
                'session': session.toSummaryJson(),
                'snapshot': session.snapshot.toJson(),
              }),
            ),
          ],
        );
      },
    );
  }

  CallToolResult _handleListSessions(CallToolRequest request) {
    final sessions = store.sessions.map((s) => s.toSummaryJson()).toList();
    return _jsonResult({'sessions': sessions, 'total': sessions.length});
  }

  CallToolResult _handleInspectScopeTree(CallToolRequest request) {
    final args = request.arguments ?? const <String, Object?>{};
    final resolved = store.resolveSession(args['sessionId'] as String?);
    if (resolved.session == null) {
      return _errorResult(resolved.error!);
    }
    final session = resolved.session!;
    final snapshot = session.snapshot;
    final includeRegistrations = args['includeRegistrations'] as bool? ?? true;
    final rootScopeId = args['rootScopeId'] as int?;

    final depsByScope = <int, List<Map<String, dynamic>>>{};
    if (includeRegistrations) {
      for (final dep in snapshot.dependencies.values) {
        depsByScope.putIfAbsent(dep.scopeId, () => []).add(dep.toJson());
      }
    }

    final childrenByParent = <int?, List<LevitScopeModel>>{};
    for (final scope in snapshot.scopes.values) {
      final parentKey =
          (scope.parentScopeId != null &&
                  snapshot.scopes.containsKey(scope.parentScopeId))
              ? scope.parentScopeId
              : null;
      childrenByParent.putIfAbsent(parentKey, () => []).add(scope);
    }

    Map<String, dynamic> buildNode(LevitScopeModel scope, Set<int> visited) {
      visited.add(scope.id);
      final children = <Map<String, dynamic>>[];
      for (final child in childrenByParent[scope.id] ?? const []) {
        if (!visited.contains(child.id)) {
          children.add(buildNode(child, visited));
        }
      }
      return {
        'id': scope.id,
        'name': scope.name,
        'parentScopeId': scope.parentScopeId,
        if (scope.progress.isNotEmpty) 'progress': scope.progress,
        if (includeRegistrations)
          'dependencies': depsByScope[scope.id] ?? const [],
        'children': children,
      };
    }

    if (rootScopeId != null) {
      final root = snapshot.scopes[rootScopeId];
      if (root == null) {
        return _errorResult(
          'Scope $rootScopeId not found in session "${session.sessionId}".',
        );
      }
      return _jsonResult({
        'sessionId': session.sessionId,
        'roots': [buildNode(root, <int>{})],
      });
    }

    final roots = <Map<String, dynamic>>[];
    final visited = <int>{};
    for (final scope in childrenByParent[null] ?? const []) {
      roots.add(buildNode(scope, visited));
    }

    return _jsonResult({
      'sessionId': session.sessionId,
      'scopeCount': snapshot.scopes.length,
      'roots': roots,
    });
  }

  CallToolResult _handleInspectReactiveGraph(CallToolRequest request) {
    final args = request.arguments ?? const <String, Object?>{};
    final resolved = store.resolveSession(args['sessionId'] as String?);
    if (resolved.session == null) {
      return _errorResult(resolved.error!);
    }
    final session = resolved.session!;
    final snapshot = session.snapshot;
    final ownerId = args['ownerId'] as String?;
    final scopeId = args['scopeId'] as int?;
    final nameContains = (args['nameContains'] as String?)?.toLowerCase();
    final orphansOnly = args['orphansOnly'] as bool? ?? false;
    final limit = (args['limit'] as int? ?? 100).clamp(1, 500);

    final matched = <LevitReactiveModel>[];
    for (final variable in snapshot.variables.values) {
      if (ownerId != null && variable.ownerId != ownerId) continue;
      if (scopeId != null && variable.scopeId != scopeId) continue;
      if (nameContains != null &&
          !variable.name.toLowerCase().contains(nameContains)) {
        continue;
      }
      if (orphansOnly &&
          variable.ownerId != null &&
          variable.ownerId!.isNotEmpty &&
          variable.ownerId != '?') {
        continue;
      }
      matched.add(variable);
    }

    final sliced = matched.take(limit).toList();
    final edges = <Map<String, int>>[];
    for (final v in sliced) {
      for (final depId in v.dependencies) {
        edges.add({'from': depId, 'to': v.id});
      }
    }

    return _jsonResult({
      'sessionId': session.sessionId,
      'totalMatched': matched.length,
      'truncated': matched.length > sliced.length,
      'droppedVariables': snapshot.droppedVariables,
      'variables': sliced.map((v) => v.toJson()).toList(),
      'edges': edges,
    });
  }

  CallToolResult _handleQueryTimeline(CallToolRequest request) {
    final args = request.arguments ?? const <String, Object?>{};
    final resolved = store.resolveSession(args['sessionId'] as String?);
    if (resolved.session == null) {
      return _errorResult(resolved.error!);
    }
    final session = resolved.session!;
    final snapshot = session.snapshot;
    final category = args['category'] as String?;
    final type = args['type'] as String?;
    final scopeId = args['scopeId'] as int?;
    final reactiveId = args['reactiveId'] as int?;
    final sinceSeq = args['sinceSeq'] as int?;
    final limit = (args['limit'] as int? ?? 50).clamp(1, 200);

    final filtered = <Map<String, dynamic>>[];
    for (final envelope in snapshot.events) {
      final data = envelope.data;
      if (category != null && data['category'] != category) continue;
      if (type != null && envelope.type != type) continue;
      if (scopeId != null && data['scopeId'] != scopeId) continue;
      if (reactiveId != null &&
          data['reactiveId']?.toString() != '$reactiveId') {
        continue;
      }
      final seq = data['seq'];
      if (sinceSeq != null && (seq is! int || seq <= sinceSeq)) {
        continue;
      }
      filtered.add(data);
    }

    final start = filtered.length > limit ? filtered.length - limit : 0;
    final slice = filtered.sublist(start);

    return _jsonResult({
      'sessionId': session.sessionId,
      'totalMatched': filtered.length,
      'returned': slice.length,
      'droppedHistoryEvents': snapshot.droppedHistoryEvents,
      'events': slice,
    });
  }

  CallToolResult _handleInspectTaskTree(CallToolRequest request) {
    final args = request.arguments ?? const <String, Object?>{};
    final resolved = store.resolveSession(args['sessionId'] as String?);
    if (resolved.session == null) {
      return _errorResult(resolved.error!);
    }
    final session = resolved.session!;
    final ownerPath = args['ownerPath'] as String?;
    final depthLimit = (args['maxDepth'] as int? ?? 8).clamp(
      1,
      maxTaskTreeDepth,
    );

    final trees = session.snapshot.taskTrees;
    if (ownerPath != null) {
      final tree = trees[ownerPath];
      if (tree == null) {
        return _errorResult(
          'Task tree for "$ownerPath" not found in session "${session.sessionId}".',
        );
      }
      return _jsonResult({
        'sessionId': session.sessionId,
        'taskTrees': {ownerPath: _boundDepth(tree, depthLimit)},
      });
    }

    return _jsonResult({
      'sessionId': session.sessionId,
      'count': trees.length,
      'taskTrees': {
        for (final entry in trees.entries)
          entry.key: _boundDepth(entry.value, depthLimit),
      },
    });
  }

  CallToolResult _handleDiagnoseRuntime(CallToolRequest request) {
    final args = request.arguments ?? const <String, Object?>{};
    final resolved = store.resolveSession(args['sessionId'] as String?);
    if (resolved.session == null) {
      return _errorResult(resolved.error!);
    }
    final session = resolved.session!;
    final threshold =
        args['highListenerThreshold'] as int? ??
        LevitRuntimeDiagnostics.defaultHighListenerThreshold;
    final findings = LevitRuntimeDiagnostics.analyze(
      session,
      highListenerThreshold: threshold,
    );

    return _jsonResult({
      'sessionId': session.sessionId,
      'healthy': findings.isEmpty,
      'findingCount': findings.length,
      'findings': findings.map((f) => f.toJson()).toList(),
    });
  }

  static Object? _boundDepth(Object? value, int remainingDepth) {
    if (value is Map) {
      if (remainingDepth <= 0) return const {'truncated': true};
      return {
        for (final entry in value.entries)
          entry.key.toString(): _boundDepth(entry.value, remainingDepth - 1),
      };
    }
    if (value is List) {
      if (remainingDepth <= 0) return const ['<truncated>'];
      return [for (final item in value) _boundDepth(item, remainingDepth - 1)];
    }
    return value;
  }

  static CallToolResult _jsonResult(Map<String, Object?> payload) =>
      CallToolResult(content: [TextContent(text: _encodeJson(payload))]);

  static CallToolResult _errorResult(String message) =>
      CallToolResult(isError: true, content: [TextContent(text: message)]);

  static String _encodeJson(Object payload) =>
      const JsonEncoder.withIndent('  ').convert(payload);
}
