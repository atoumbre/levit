import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';
import 'package:nexus_studio_shared/shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Controller for handling real-time presence (cursors, users).
class PresenceController extends LevitController {
  /// Track of all other users in the session.
  final remoteUsers = <String, RemoteUser>{}.lx.named('remoteUsers');

  /// The local user's info.
  final localUserId = 'user_${DateTime.now().millisecond}';
  late final String localUserName;
  late final int localColor;

  @override
  void onInit() {
    super.onInit();
    localUserName = 'Designer ${localUserId.substring(localUserId.length - 3)}';
    localColor = 0xFF000000 | (localUserId.hashCode & 0xFFFFFF);
  }

  /// Updates the local cursor and broadcasts to others.
  void updateLocalCursor(Offset offset) {
    final pc = Levit.find<ProjectController>();
    pc.sendPresenceUpdate(Vec2(offset.dx, offset.dy));
  }

  /// Handles incoming presence messages from the server.
  void handlePresenceMessage(Map<String, dynamic> data) {
    final String id = data['senderId'];
    if (id == localUserId) return;

    final pos = Vec2.fromJson(data['cursor']);

    if (remoteUsers.containsKey(id)) {
      remoteUsers[id]!.cursor.value = pos;
    } else {
      // New user joined
      remoteUsers[id] = RemoteUser(
        id: id,
        name: data['name'] ?? 'Guest',
        color: data['color'] ?? 0xFFFFFFFF,
        cursorPos: pos,
      );
    }
  }

  /// Removes a user from the session.
  void removeUser(String id) {
    remoteUsers.remove(id);
  }
}

/// The client-side orchestrator for Nexus Studio.
/// Demonstrates high-performance sync, computed logic, and stream handling.
class ProjectController extends LevitController {
  /// The shared game engine logic (isomorphic).
  late final engine = own(NexusEngine());

  /// The set of currently selected node IDs.
  final selectedIds = <String>{}.lx.named('selectedIds');

  WebSocketChannel? _channel;
  final WebSocketChannel Function(Uri) _connectFn;
  final Duration _exportDelay;
  final LxStream<String>? _sessionTimerOverride;

  /// Creates a project controller.
  ProjectController({
    this._channel,
    WebSocketChannel Function(Uri)? connector,
    this._exportDelay = const Duration(seconds: 2),
    LxStream<String>? sessionTimer,
  }) : _connectFn = connector ?? WebSocketChannel.connect,
       _sessionTimerOverride = sessionTimer;

  /// Showcase: LxFuture (Pillar 6)
  /// Represents the status of a cloud export operation.
  final exportStatus = LxVar<LxFuture<String>?>(null);

  /// Showcase: LxComputed (Pillar 1)
  /// This box wraps all selected elements. It recomputes automatically
  /// whenever any selected node moves, or when the selection set changes.
  late final LxComputed<Rect?> selectionBounds;

  /// Explicit, bounded local edits with inverse server messages.
  late final history = own(
    NexusCommandHistory(
      engine,
      send: (message) {
        _channel?.sink.add(jsonEncode(message));
      },
    ),
  );

  /// Showcase: LxStream (Pillar 6)
  /// Tracks session duration reactively
  late final LxStream<String> sessionTimer;

  /// Showcase: Lx.select (Pillar 6)
  /// Optimized derived state that only updates when node count changes
  late final LxComputed<int> nodeCount;

  /// Whether undo is available.
  bool get canUndo => history.canUndo;

  /// Whether redo is available.
  bool get canRedo => history.canRedo;

  @override
  void onInit() {
    super.onInit();
    own(exportStatus);

    // Initialize the computed property with auto-dispose tracking
    selectionBounds = own(
      LxComputed(() {
        final selectedNodes = engine.nodes.where(
          (n) => selectedIds.contains(n.id),
        );
        return NexusEngine.calculateBounds(selectedNodes);
      }).named('selectionBounds'),
    );

    // Showcase: Lx.select (Pillar 6)
    // Optimization: Only notifies when length changes, ignoring other node updates
    nodeCount = (() => engine.nodes.length).lx;

    // Showcase: LxStream (Pillar 6)
    // Wraps a Dart Stream into a reactive Lx value
    sessionTimer = own(
      _sessionTimerOverride ??
          LxStream<String>(
            Stream.periodic(const Duration(seconds: 1), (i) {
              final duration = Duration(seconds: i);
              return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
            }),
            initial: '0:00',
          ),
    );

    _connect();
  }

  void _connect() {
    try {
      if (_channel == null) {
        final uri = Uri.parse('ws://localhost:8080');
        _channel = _connectFn(uri);
      }

      // Showcase: LxStream (Pillar 4)
      // Wrap WebSocket in LxStream to track connection status (Success, Error, Waiting)
      final connection = own(LxStream(_channel!.stream.cast<String>()));

      own(
        LxWorker(connection, (status) {
          if (status is LxSuccess<String>) {
            _handleServerMessage(jsonDecode(status.value));
          } else if (status is LxError) {
            // Reconnect logic or error reporting
          }
        }),
      );
    } catch (_) {
      // Background connection failure handled by LxStream
    }
  }

  void _handleServerMessage(Map<String, dynamic> data) {
    final type = data['type'];

    if (type == 'presence_update') {
      (scope?.findOrNull<PresenceController>() ??
              Levit.findOrNull<PresenceController>())
          ?.handlePresenceMessage(data);
      return;
    }
    Lx.batch(() {
      if (history.receiveDocument(data)) {
        _isDragging = false;
        _dragStartPositions.clear();
        selectedIds.removeWhere(
          (id) => !engine.nodes.any((node) => node.id == id),
        );
      }
    });
  }

  // Track if we're in the middle of a drag operation
  bool _isDragging = false;
  Map<String, Vec2> _dragStartPositions = {};

  /// Called when drag starts - captures start positions for undo.
  void startDrag() {
    if (_isDragging) return;
    _isDragging = true;

    // Capture starting positions for later history entry
    _dragStartPositions = {
      for (final id in selectedIds)
        for (final node in engine.nodes)
          if (node.id == id) id: node.position.value,
    };
  }

  /// Called when drag ends - creates single history entry and syncs to server.
  void endDrag() {
    if (!_isDragging) return;
    _isDragging = false;
    final after = <String, Vec2>{
      for (final node in engine.nodes)
        if (_dragStartPositions.containsKey(node.id))
          node.id: node.position.value,
    };
    final before = <String, Vec2>{
      for (final id in after.keys) id: _dragStartPositions[id]!,
    };
    _dragStartPositions.clear();
    history.execute(MoveNodesCommand(before, after));
  }

  /// Previews a drag, or executes one position command for a discrete move.
  void moveSelection(Vec2 delta) {
    if (selectedIds.isEmpty) return;
    if (!(scope?.find<AuthController>() ?? Levit.find<AuthController>())
        .canEdit) {
      return;
    }
    final before = {
      for (final node in engine.nodes)
        if (selectedIds.contains(node.id)) node.id: node.position.value,
    };
    final after = before.map((id, position) => MapEntry(id, position + delta));
    if (_isDragging) {
      engine.bulkUpdate(after);
    } else {
      history.execute(MoveNodesCommand(before, after));
    }
  }

  /// Select or deselect a node.
  void toggleSelection(String id, {bool multi = false}) {
    if (!multi) {
      if (selectedIds.length == 1 && selectedIds.contains(id)) {
        selectedIds.clear();
      } else {
        selectedIds.assignOne(id);
      }
    } else {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
    }
    debugPrint('   After: $selectedIds');
  }

  /// Reverts the latest local command and sends its inverse.
  void undo() => history.undo();

  /// Reapplies the latest reverted local command.
  void redo() => history.redo();

  /// Changes selected colors as one atomic, synchronized command.
  void colorSelection(int color) {
    if (!(scope?.find<AuthController>() ?? Levit.find<AuthController>())
        .canEdit) {
      return;
    }
    final before = {
      for (final node in engine.nodes)
        if (selectedIds.contains(node.id)) node.id: node.color.value,
    };
    history.execute(
      ColorNodesCommand(before, {for (final id in before.keys) id: color}),
    );
  }

  /// Showcase: Presence (Pillar 4)
  void sendPresenceUpdate(Vec2 cursor) {
    try {
      final presence = Levit.find<PresenceController>();
      _channel?.sink.add(
        jsonEncode({
          'type': 'presence_update',
          'cursor': cursor.toJson(),
          'name': presence.localUserName,
          'color': presence.localColor,
        }),
      );
    } catch (_) {}
  }

  /// Showcase: LxFuture (Pillar 6)
  /// Triggers a simulated cloud export with reactive status tracking.
  void export() {
    exportStatus.value = own(
      LxFuture(() async {
        await Future.delayed(_exportDelay);
        if (engine.nodes.isEmpty) {
          throw Exception('Cannot export empty project');
        }
        return 'Project exported successfully at ${DateTime.now().hour}:${DateTime.now().minute}';
      }()),
    );
  }

  /// Showcase: Batch Updates & Sync
  /// Randomizes node positions and syncs to all clients.
  void chaos() {
    final before = {
      for (final node in engine.nodes) node.id: node.position.value,
    };
    final after = before.map(
      (id, position) => MapEntry(
        id,
        position +
            Vec2(
              (DateTime.now().microsecond % 20 - 10).toDouble(),
              (DateTime.now().millisecond % 20 - 10).toDouble(),
            ),
      ),
    );
    history.execute(MoveNodesCommand(before, after));
  }

  /// Adds a new node to the project and syncs it.
  void addNode(String type) {
    // Determine spawn position (center of default viewport + noise)
    final pos = Vec2(
      200.0 + (DateTime.now().millisecond % 100),
      200.0 + (DateTime.now().microsecond % 100),
    );

    final node = NodeSnapshot(
      id: '${type}_${DateTime.now().microsecondsSinceEpoch}_${_nextNodeId++}',
      type: type,
      position: pos,
      size: type == 'rect'
          ? const Vec2(100, 100)
          : type == 'circle'
          ? const Vec2(100, 100)
          : const Vec2(120, 100), // triangle slightly wider
      color: 0xFF000000 | (DateTime.now().microsecond & 0xFFFFFF),
    );

    history.execute(CreateNodeCommand(node));
  }

  static int _nextNodeId = 0;

  @override
  Future<void> onClose() async {
    try {
      await super.onClose();
    } finally {
      await _channel?.sink.close();
    }
  }
}

/// Represents a logged-in user session.
class UserSession {
  /// The user ID.
  final String userId;

  /// The user email.
  final String email;

  /// The user role (e.g., 'editor', 'viewer').
  final String role; // 'editor' or 'viewer'

  /// Creates a user session.
  UserSession({
    required this.userId,
    required this.email,
    this.role = 'editor',
  });
}

/// Controller for authentication.
class AuthController extends LevitController {
  /// The current user session (null if logged out).
  final session = LxVar<UserSession?>(null).named('session');

  /// Whether a user is currently logged in.
  bool get isAuthenticated => session.value != null;

  /// Pillar 1: Computed permission
  /// Whether the current user has editing rights.
  bool get canEdit {
    final s = session.value;
    if (s == null) return false;
    return s.role == 'editor';
  }

  /// Logs in a user with the given email.
  void login(String email) {
    // Simulate API call
    // Simulate API call
    session.value = UserSession(
      userId: 'user_${email.hashCode}',
      email: email,
      role: email.contains('viewer') ? 'viewer' : 'editor',
    );
  }

  /// Logs out the current user.
  void logout() {
    session.value = null;
  }
}
