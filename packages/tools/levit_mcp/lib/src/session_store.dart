/// @docImport 'websocket_relay.dart';
library;

import 'dart:collection';

import 'package:levit_monitor/spi.dart';

/// State and telemetry metadata for one monitored Levit application session.
///
/// {@category Session & Diagnostics}
final class LevitMcpSession {
  /// Stable session identifier reported by the producer or assigned on connect.
  final String sessionId;

  /// Optional human-readable application identifier (`?appId=`).
  String? appId;

  /// Whether at least one producer WebSocket is currently attached.
  bool connected;

  /// Timestamp when this session was first created.
  final DateTime createdAt;

  /// Timestamp of the most recent connection or event activity.
  DateTime lastActivityAt;

  /// Total number of envelopes applied to this session.
  int eventCount = 0;

  /// Bounded redacted shadow state reconstructed from incoming events.
  final LevitStateSnapshot snapshot;

  // Bounded ring of recent error envelopes (`reactive_error` or error logs).
  final ListQueue<Map<String, dynamic>> _recentErrors = ListQueue();

  /// Maximum error entries retained per session.
  final int maxRecentErrors;

  /// Creates a new session record initialized at [now].
  ///
  /// Allocates a bounded [LevitStateSnapshot] with [historyCapacity] events and
  /// [maxVariables] reactive variables, and caps [recentErrors] at
  /// [maxRecentErrors] (defaults to `50`).
  LevitMcpSession({
    required this.sessionId,
    this.appId,
    required this.connected,
    required DateTime now,
    required int historyCapacity,
    required int maxVariables,
    this.maxRecentErrors = 50,
  }) : createdAt = now,
       lastActivityAt = now,
       snapshot = LevitStateSnapshot(
         maxEvents: historyCapacity,
         maxVariables: maxVariables,
       );

  /// Unmodifiable view of recent error summaries for this session.
  List<Map<String, dynamic>> get recentErrors =>
      List.unmodifiable(_recentErrors);

  /// Records an error payload into the bounded FIFO error ring.
  ///
  /// Evicts the oldest entry when [maxRecentErrors] is already reached.
  void recordError(Map<String, dynamic> errorSummary) {
    if (_recentErrors.length == maxRecentErrors) {
      _recentErrors.removeFirst();
    }
    _recentErrors.add(errorSummary);
  }

  /// Summarizes this session for `list_sessions` and `levit://sessions`.
  Map<String, dynamic> toSummaryJson() => {
    'sessionId': sessionId,
    'appId': appId,
    'connected': connected,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'lastActivityAt': lastActivityAt.toUtc().toIso8601String(),
    'eventCount': eventCount,
    'scopeCount': snapshot.scopes.length,
    'dependencyCount': snapshot.dependencies.length,
    'variableCount': snapshot.variables.length,
    'taskTreeCount': snapshot.taskTrees.length,
    'errorCount': _recentErrors.length,
    'droppedHistoryEvents': snapshot.droppedHistoryEvents,
    'droppedVariables': snapshot.droppedVariables,
  };
}

/// Multi-session bounded store backing [LevitWebSocketRelay] and MCP tools.
///
/// {@category Session & Diagnostics}
final class LevitSessionStore {
  /// Maximum number of tracked sessions retained simultaneously.
  final int maxSessions;

  /// Maximum number of recent events retained in each session's snapshot.
  final int historyCapacity;

  /// Maximum number of reactive variables tracked in each session's snapshot.
  final int maxVariables;
  final DateTime Function() _clock;
  final LinkedHashMap<String, LevitMcpSession> _sessions = LinkedHashMap();

  /// Creates a bounded session store.
  ///
  /// Defaults to [maxSessions] = `16`, [historyCapacity] = `500`, and
  /// [maxVariables] = `4096`. Pass [clock] to supply deterministic timestamps
  /// in tests.
  LevitSessionStore({
    this.maxSessions = 16,
    this.historyCapacity = 500,
    this.maxVariables = 4096,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// All tracked sessions in insertion order.
  List<LevitMcpSession> get sessions => List.unmodifiable(_sessions.values);

  /// Looks up a session by exact [sessionId], or returns `null`.
  LevitMcpSession? operator [](String sessionId) => _sessions[sessionId];

  /// Registers or reactivates a session when a producer connects or emits.
  ///
  /// Throws [StateError] if [maxSessions] active sessions are already connected
  /// and no disconnected session can be evicted.
  LevitMcpSession openSession(String sessionId, {String? appId}) {
    final now = _clock();
    final existing = _sessions[sessionId];
    if (existing != null) {
      existing.connected = true;
      existing.lastActivityAt = now;
      if (appId != null && appId.isNotEmpty) {
        existing.appId = appId;
      }
      return existing;
    }

    if (_sessions.length >= maxSessions) {
      String? evictKey;
      for (final entry in _sessions.entries) {
        if (!entry.value.connected) {
          evictKey = entry.key;
          break;
        }
      }
      if (evictKey == null) {
        throw StateError('Session capacity ($maxSessions) reached.');
      }
      _sessions.remove(evictKey);
    }

    final created = LevitMcpSession(
      sessionId: sessionId,
      appId: (appId != null && appId.isNotEmpty) ? appId : null,
      connected: true,
      now: now,
      historyCapacity: historyCapacity,
      maxVariables: maxVariables,
    );
    _sessions[sessionId] = created;
    return created;
  }

  /// Marks [sessionId] as disconnected while retaining its latest snapshot.
  void markDisconnected(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;
    session.connected = false;
    session.lastActivityAt = _clock();
  }

  /// Applies an incoming [envelope] to [sessionId], opening or reactivating
  /// the session automatically.
  ///
  /// Increments [LevitMcpSession.eventCount], updates
  /// [LevitMcpSession.lastActivityAt], and records `'reactive_error'` events as
  /// well as `'log'` events with level `'error'` or `'fatal'` into
  /// [LevitMcpSession.recentErrors].
  ///
  /// Throws [StateError] if [sessionId] is new and [maxSessions] connected
  /// sessions are already active.
  LevitMcpSession applyEnvelope(
    String sessionId,
    LevitEventEnvelope envelope, {
    String? appId,
  }) {
    final session = openSession(sessionId, appId: appId);
    session.snapshot.applyEnvelope(envelope);
    session.eventCount++;
    session.lastActivityAt = _clock();

    final data = envelope.data;
    final isErrorEvent =
        envelope.type == 'reactive_error' ||
        (envelope.type == 'log' &&
            (data['level'] == 'error' || data['level'] == 'fatal'));
    if (isErrorEvent) {
      session.recordError({
        if (data['seq'] != null) 'seq': data['seq'],
        'type': envelope.type,
        'timestamp': data['timestamp'],
        if (data['reactiveId'] != null) 'reactiveId': data['reactiveId'],
        if (data['name'] != null) 'name': data['name'],
        if (data['error'] != null) 'error': data['error'],
        if (data['data'] != null) 'message': data['data'],
      });
    }
    return session;
  }

  /// Resolves a target session for an MCP tool call.
  ///
  /// When [sessionId] is omitted:
  /// - Selects the single connected session if exactly one is connected.
  /// - Otherwise selects the single retained session if exactly one exists.
  /// - Otherwise returns an explanatory error message.
  ({LevitMcpSession? session, String? error}) resolveSession(
    String? sessionId,
  ) {
    if (sessionId != null && sessionId.isNotEmpty) {
      final session = _sessions[sessionId];
      if (session == null) {
        return (
          session: null,
          error:
              'Unknown sessionId "$sessionId". '
              'Call list_sessions to see available sessions.',
        );
      }
      return (session: session, error: null);
    }

    if (_sessions.isEmpty) {
      return (
        session: null,
        error:
            'No Levit sessions have connected yet. Attach LevitMonitor with '
            'LevitWebSocketTransport.connect(...) in your app.',
      );
    }

    final connected = _sessions.values.where((s) => s.connected).toList();
    if (connected.length == 1) {
      return (session: connected.first, error: null);
    }
    if (_sessions.length == 1) {
      return (session: _sessions.values.first, error: null);
    }

    final ids = _sessions.keys.join(', ');
    return (
      session: null,
      error: 'Multiple sessions available ($ids). Specify a sessionId.',
    );
  }
}
