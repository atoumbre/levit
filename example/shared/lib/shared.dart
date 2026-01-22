import 'dart:math';

import 'package:levit_dart/levit_dart.dart';

/// A simple 2D vector for isomorphic use.
///
/// Used instead of Flutter's `Offset` to ensure server-side compatibility.
class Vec2 {
  /// X coordinate.
  final double x;

  /// Y coordinate.
  final double y;

  /// Creates a vector.
  const Vec2(this.x, this.y);

  /// Adds two vectors.
  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);

  /// Subtracts two vectors.
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);

  /// Converts to JSON map.
  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  /// Creates from JSON map.
  factory Vec2.fromJson(Map<String, dynamic> json) =>
      Vec2((json['x'] as num).toDouble(), (json['y'] as num).toDouble());

  @override
  String toString() => 'Vec2($x, $y)';
}

/// A graphical node with reactive properties.
///
/// This model runs on both Server and Client (Isomorphic).
/// It uses [Lx] properties so that changes can be tracked automatically
/// by the UI or synchronization logic.
class NodeModel {
  /// Unique identifier.
  final String id;

  /// Node type string.
  final String type;

  /// Reactive position.
  final LxVar<Vec2> position;

  /// Reactive size.
  final LxVar<Vec2> size;

  /// Reactive color value.
  final LxInt color;

  /// Creates a node model.
  NodeModel({
    required this.id,
    required this.type,
    required Vec2 pos,
    required Vec2 sz,
    required int col,
  })  : position = (pos.lx..name = 'node:$id:pos'),
        size = (sz.lx..name = 'node:$id:size'),
        color = (col.lx..name = 'node:$id:color');

  /// Serializes to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'position': position.value.toJson(),
        'size': size.value.toJson(),
        'color': color.value,
      };

  /// Deserializes from JSON.
  factory NodeModel.fromJson(Map<String, dynamic> json) => NodeModel(
        id: json['id'],
        type: json['type'],
        pos: Vec2.fromJson(json['position']),
        sz: Vec2.fromJson(json['size']),
        col: json['color'],
      );
}

/// Represents a collaborator in the studio.
class RemoteUser {
  /// User ID.
  final String id;

  /// Display name.
  final String name;

  /// Cursor color.
  final int color;

  /// Reactive cursor position.
  final LxVar<Vec2> cursor;

  /// Creates a remote user.
  RemoteUser({
    required this.id,
    required this.name,
    required this.color,
    required Vec2 cursorPos,
  }) : cursor = cursorPos.lx;

  /// Serializes to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'cursor': cursor.value.toJson(),
      };

  /// Deserializes from JSON.
  factory RemoteUser.fromJson(Map<String, dynamic> json) => RemoteUser(
        id: json['id'],
        name: json['name'],
        color: json['color'],
        cursorPos: Vec2.fromJson(json['cursor']),
      );
}

/// A simple Rect for isomorphic use.
///
/// Used instead of Flutter's `Rect` to ensure the code can run in pure Dart
/// environments (like the server).
class Rect {
  /// The left coordinate.
  final double left;

  /// The top coordinate.
  final double top;

  /// The width of the rectangle.
  final double width;

  /// The height of the rectangle.
  final double height;

  /// Creates a rectangle.
  const Rect(this.left, this.top, this.width, this.height);

  @override
  String toString() => 'Rect($left, $top, $width, $height)';
}

/// The core engine for Nexus Studio.
///
/// Handles the master state of the canvas. This class demonstrates Levit's
/// isomorphic capabilities by running identical logic on both the
/// client (Flutter) and the server (Dart).
class NexusEngine extends LevitController {
  /// The collection of all nodes on the canvas.
  ///
  /// Using [LxList] allows for fine-grained reactivity. The UI only updates
  /// when nodes are added or removed, not when individual node properties change
  /// (since those are tracked separately).
  final nodes = <NodeModel>[].lx..name = 'engine:nodes';

  /// Add a node to the engine.
  void addNode(NodeModel node) {
    nodes.add(node);
  }

  /// Remove a node by [id].
  void removeNode(String id) {
    nodes.removeWhere((n) => n.id == id);
  }

  /// Bulk move multiple nodes.
  ///
  /// This method demonstrates the power of [Lx.batch]. Moving 1,000 nodes
  /// individually would trigger 1,000 notifications/rebuilds. With batching,
  /// it triggers exactly ONE notification cycle, providing massive performance
  /// gains (10x-50x) in complex scenes.
  ///
  /// *   [ids]: The IDs of the nodes to move.
  /// *   [delta]: The amount to move them by.
  void bulkMove(Set<String> ids, Vec2 delta) {
    Lx.batch(() {
      for (final node in nodes) {
        if (ids.contains(node.id)) {
          node.position.value += delta;
        }
      }
    });
  }

  /// Update positions of specific nodes absolutely.
  ///
  /// *   [positions]: A map of node ID to new position.
  void bulkUpdate(Map<String, Vec2> positions) {
    Lx.batch(() {
      for (final node in nodes) {
        if (positions.containsKey(node.id)) {
          node.position.value = positions[node.id]!;
        }
      }
    });
  }

  /// Update colors of specific nodes.
  ///
  /// *   [colors]: A map of node ID to new color value.
  void bulkColor(Map<String, int> colors) {
    Lx.batch(() {
      for (final node in nodes) {
        if (colors.containsKey(node.id)) {
          node.color.value = colors[node.id]!;
        }
      }
    });
  }

  /// Calculates the bounding box of a set of [selectedNodes].
  ///
  /// This function is often used within an [LxComputed] to create an auto-updating
  /// selection box. The bounds will recompute whenever the selection changes
  /// OR whenever any selected node moves or resizes.
  static Rect? calculateBounds(Iterable<NodeModel> selectedNodes) {
    if (selectedNodes.isEmpty) return null;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final node in selectedNodes) {
      final pos = node.position.value;
      final size = node.size.value;
      minX = min(minX, pos.x);
      minY = min(minY, pos.y);
      maxX = max(maxX, pos.x + size.x);
      maxY = max(maxY, pos.y + size.y);
    }

    return Rect(minX, minY, maxX - minX, maxY - minY);
  }

  @override
  void onInit() {
    super.onInit();
    autoDispose(nodes);
  }
}
