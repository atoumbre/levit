import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared/shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Controller for handling real-time presence (cursors, users).
class PresenceController extends LevitController {
  /// Track of all other users in the session.
  final remoteUsers = <String, RemoteUser>{}.lx;

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
  final engine = NexusEngine();

  /// The set of currently selected node IDs.
  final selectedIds = <String>{}.lx;

  WebSocketChannel? _channel;
  final WebSocketChannel Function(Uri)? _connector;

  /// Creates a project controller.
  ProjectController({
    WebSocketChannel? channel,
    WebSocketChannel Function(Uri)? connector,
  })  : _channel = channel,
        _connector = connector;

  /// Showcase: LxFuture (Pillar 6)
  /// Represents the status of a cloud export operation.
  final exportStatus = LxVar<LxFuture<String>?>(null);

  /// Showcase: LxComputed (Pillar 1)
  /// This box wraps all selected elements. It recomputes automatically
  /// whenever any selected node moves, or when the selection set changes.
  late final LxComputed<Rect?> selectionBounds;

  /// Showcase: HistoryMiddleware (Pillar 3)
  final history = LevitReactiveHistoryMiddleware();
  LevitReactiveMiddleware? _activeHistoryMiddleware;

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

    // Initialize the computed property with auto-dispose tracking
    selectionBounds = autoDispose(
      LxComputed(() {
        final selectedNodes = engine.nodes.where(
          (n) => selectedIds.contains(n.id),
        );
        return NexusEngine.calculateBounds(selectedNodes);
      }),
    );

    // Showcase: Lx.select (Pillar 6)
    // Optimization: Only notifies when length changes, ignoring other node updates
    nodeCount = (() => engine.nodes.length).lx;

    // Register history middleware with named filter
    _activeHistoryMiddleware = Lx.addMiddleware(
      _FilteredMiddleware(
        history,
        (reactive, change) {
          final name = reactive.name;
          if (name == null) return false;
          return name == 'engine:nodes' || name.startsWith('node:');
        },
      ),
    );

    // Showcase: LxStream (Pillar 6)
    // Wraps a Dart Stream into a reactive Lx value
    sessionTimer = LxStream<String>(
      Stream.periodic(const Duration(seconds: 1), (i) {
        final duration = Duration(seconds: i);
        return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
      }),
      initial: '0:00',
    );

    _connect();
  }

  void _connect() {
    try {
      if (_channel == null) {
        final uri = Uri.parse('ws://localhost:8080');
        _channel = _connector != null
            ? _connector!(uri)
            : WebSocketChannel.connect(uri);
      }

      // Showcase: LxStream (Pillar 4)
      // Wrap WebSocket in LxStream to track connection status (Success, Error, Waiting)
      final connection = LxStream(_channel!.stream.cast<String>());

      autoDispose(
        LxWatch(connection, (status) {
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

    // Showcase: LxList.assign (Pillar 2)
    // Replaces entire list logic without triggering individual "add" notifications
    if (type == 'snapshot') {
      final List nodesData = data['nodes'];
      engine.nodes.assign(nodesData.map((n) => NodeModel.fromJson(n)));
    } else if (type == 'bulk_move') {
      final ids = Set<String>.from(data['ids']);
      final delta = Vec2.fromJson(data['delta']);

      debugPrint('📥 Remote move received: ${ids.length} nodes');

      // Apply mutation locally without triggering local history sync
      Lx.runWithoutMiddleware(() {
        engine.bulkMove(ids, delta);
      });
    } else if (type == 'bulk_update') {
      final Map<String, dynamic> posData = data['positions'];
      final updates = posData.map((k, v) => MapEntry(k, Vec2.fromJson(v)));

      // Pillar 3: Use runWithoutMiddleware to avoid recording server syncs in local history
      Lx.runWithoutMiddleware(() {
        engine.bulkUpdate(updates);
      });
    } else if (type == 'presence_update') {
      final presence = Levit.findOrNull<PresenceController>();
      presence?.handlePresenceMessage(data);
    } else if (type == 'bulk_color') {
      final Map<String, dynamic> colorData = data['colors'];
      Lx.runWithoutMiddleware(() {
        for (final node in engine.nodes) {
          if (colorData.containsKey(node.id)) {
            node.color.value = colorData[node.id] as int;
          }
        }
      });
    } else if (type == 'node_create') {
      final nodeData = data['node'];
      final node = NodeModel.fromJson(nodeData);
      Lx.runWithoutMiddleware(() {
        engine.addNode(node);
      });
    }
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

    // Create a single atomic undo operation for the entire drag
    if (_dragStartPositions.isNotEmpty) {
      // Capture current (end) positions
      final endPositions = <String, Vec2>{};
      for (final entry in _dragStartPositions.entries) {
        final node = engine.nodes.firstWhere(
          (n) => n.id == entry.key,
          orElse: () => engine.nodes.first,
        );
        if (node.id == entry.key) {
          endPositions[entry.key] = node.position.value;
        }
      }

      // Restore to start positions WITHOUT middleware
      Lx.runWithoutMiddleware(() {
        for (final entry in _dragStartPositions.entries) {
          final node = engine.nodes.firstWhere(
            (n) => n.id == entry.key,
            orElse: () => engine.nodes.first,
          );
          if (node.id == entry.key) {
            node.position.value = entry.value;
          }
        }
      });

      // Now set to end positions WITH middleware - this creates the history entry
      Lx.batch(() {
        for (final entry in endPositions.entries) {
          final node = engine.nodes.firstWhere(
            (n) => n.id == entry.key,
            orElse: () => engine.nodes.first,
          );
          if (node.id == entry.key) {
            node.position.value = entry.value;
          }
        }
      });
    }

    _dragStartPositions.clear();
    _syncAllPositions();
  }

  /// Move selected nodes (called during drag - no history recorded).
  void moveSelection(Vec2 delta) {
    if (selectedIds.isEmpty) return;

    // Pillar 1: Check permissions (reactive)
    if (!Levit.find<AuthController>().canEdit) return;

    // Update positions WITHOUT recording history (we record at drag end)
    Lx.runWithoutMiddleware(() {
      for (final node in engine.nodes) {
        if (selectedIds.contains(node.id)) {
          node.position.value += delta;
        }
      }
    });
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

  /// Showcase: History (Pillar 3)
  void undo() {
    debugPrint(
      '🔄 Undo requested. canUndo: ${history.canUndo}, stack size: ${history.length}',
    );
    if (history.undo()) {
      debugPrint('✅ Undo successful');
      _syncAllPositions();
    } else {
      debugPrint('❌ Undo failed - no history');
    }
  }

  /// Redo the last undone action.
  void redo() {
    debugPrint('🔄 Redo requested. canRedo: ${history.canRedo}');
    if (history.redo()) {
      debugPrint('✅ Redo successful');
      _syncAllPositions();
    } else {
      debugPrint('❌ Redo failed - no redo stack');
    }
  }

  void _syncAllPositions() {
    final positions = {
      for (final n in engine.nodes) n.id: n.position.value.toJson(),
    };
    _channel?.sink.add(
      jsonEncode({'type': 'bulk_update', 'positions': positions}),
    );
  }

  /// Sync color changes to the server.
  void syncColors() {
    final colors = {for (final n in engine.nodes) n.id: n.color.value};
    _channel?.sink.add(jsonEncode({'type': 'bulk_color', 'colors': colors}));
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
    exportStatus.value = LxFuture(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (engine.nodes.isEmpty) throw Exception('Cannot export empty project');
      return 'Project exported successfully at ${DateTime.now().hour}:${DateTime.now().minute}';
    }());
  }

  /// Showcase: Batch Updates & Sync
  /// Randomizes node positions and syncs to all clients.
  void chaos() {
    Lx.batch(() {
      for (final node in engine.nodes) {
        node.position.value += Vec2(
          (DateTime.now().microsecond % 20 - 10).toDouble(),
          (DateTime.now().millisecond % 20 - 10).toDouble(),
        );
      }
    });
    _syncAllPositions();
  }

  /// Adds a new node to the project and syncs it.
  void addNode(String type) {
    // Determine spawn position (center of default viewport + noise)
    final pos = Vec2(
      200.0 + (DateTime.now().millisecond % 100),
      200.0 + (DateTime.now().microsecond % 100),
    );

    final node = NodeModel(
      id: '${type}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      pos: pos,
      sz: type == 'rect'
          ? const Vec2(100, 100)
          : type == 'circle'
              ? const Vec2(100, 100)
              : const Vec2(120, 100), // triangle slightly wider
      col: 0xFF000000 | (DateTime.now().microsecond & 0xFFFFFF),
    );

    // Add locally (history recorded automatically by middleware)
    engine.addNode(node);

    // Send to server
    _channel?.sink.add(
      jsonEncode({'type': 'node_create', 'node': node.toJson()}),
    );
  }

  @override
  void onClose() {
    if (_activeHistoryMiddleware != null) {
      Lx.removeMiddleware(_activeHistoryMiddleware!);
    }
    _channel?.sink.close();
    super.onClose();
  }
}

class _FilteredMiddleware extends LevitReactiveMiddleware {
  final LevitReactiveMiddleware inner;
  final bool Function(LxReactive, LevitReactiveChange) filter;

  _FilteredMiddleware(this.inner, this.filter);

  @override
  LxOnSet? get onSet => inner.onSet == null
      ? null
      : (next, reactive, change) {
          if (filter(reactive, change)) {
            return inner.onSet!(next, reactive, change);
          }
          return next;
        };

  @override
  LxOnBatch? get onBatch => inner.onBatch == null
      ? null
      : (next, change) {
          // For batch, we ideally filter the entries, but LevitReactiveBatch is immutable.
          // However, inner.onBatch logic handles the batch as a whole.
          // If we want to filter specific ops inside batch, we can't easily.
          // Assuming if ANY matches or ALL match?
          // HistoryMiddleware usually records the whole batch.
          // Let's pass through batch to inner, or assume filter is for onSet only?
          // The previous code had (reactive, change) filter.
          // So likely per-operation check.
          // If strict compliance: we check if batch contains interesting items?
          // Or just delegate.
          return inner.onBatch!(next, change);
        };
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
  final session = LxVar<UserSession?>(null);

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
