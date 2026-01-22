import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared/shared.dart';
import 'package:nexus_studio_app/controllers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Registering Core Controllers...');

  // Pillar 5: Scoped DI (Standardizing on global registry for app-wide services)
  // Showcase: Levit.lazyPut (Pillar 6)
  // Lazily initializes the controller only when first accessed
  Levit.lazyPut(() => AuthController());
  Levit.put(() => PresenceController());
  Levit.put(() => ProjectController());

  debugPrint('✅ DI Registration Complete: ${Levit.registeredKeys}');

  runApp(const NexusStudioApp());
}

/// The main application widget for Nexus Studio.
class NexusStudioApp extends StatelessWidget {
  const NexusStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
      ),
      home: const EditorPage(),
    );
  }
}

/// The primary editor interface.
class EditorPage extends StatelessWidget {
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = Levit.find<ProjectController>();

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          const PropertySidebar(),

          // Main Canvas
          Expanded(
            child: Stack(
              children: [
                // Grid Background
                const GridBackground(),

                // Canvas Interaction Layer
                MouseRegion(
                  onHover: (event) {
                    Levit.find<PresenceController>().updateLocalCursor(
                      event.localPosition,
                    );
                  },
                  child: Container(
                    color: Colors.transparent,
                    child: LWatch(
                      () => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 1. Background Tap Detector (Fill)
                          // Only receives taps that miss the nodes on top
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () {
                                pc.selectedIds.clear();
                              },
                              child: Container(color: Colors.transparent),
                            ),
                          ),

                          // 2. Nodes (on top)
                          ...pc.engine.nodes.map(
                            (node) =>
                                NodeWidget(key: ValueKey(node.id), node: node),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Multi-User Presence Layer
                IgnorePointer(child: const PresenceOverlay()),

                // Selection Bounds (Pillar 1: Computed)
                LWatch(() {
                  final bounds = pc.selectionBounds.value;
                  if (bounds == null) return const SizedBox();
                  return Positioned(
                    left: bounds.left - 4,
                    top: bounds.top - 4,
                    child: IgnorePointer(
                      child: Container(
                        width: bounds.width + 8,
                        height: bounds.height + 8,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.blueAccent.withValues(alpha: 0.8),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // HUD
                const _TopBar(),

                // Login Overlay (Pillar 1: Reactive visibility)
                const _LoginOverlay(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: LWatch(
        () => FloatingActionButton.extended(
          onPressed: Levit.find<AuthController>().canEdit
              ? () {
                  // Chaos Mode: Move nodes randomly
                  pc.chaos();
                }
              : null,
          label: const Text('CHAOS MODE'),
          icon: const Icon(Icons.bolt),
          backgroundColor: Levit.find<AuthController>().canEdit
              ? Colors.amber
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

/// A widget representing a single node on the canvas.
class NodeWidget extends StatelessWidget {
  final NodeModel node;
  const NodeWidget({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final pc = Levit.find<ProjectController>();

    // 1. Outer Scope: Position & Size (Layout)
    // Only rebuilds when node moves or resizes.
    return LWatch(() {
      final pos = node.position.value;
      final size = node.size.value;

      return Positioned(
        left: pos.x,
        top: pos.y,
        // 2. Stable Gesture Layer
        // Does NOT rebuild on selection changes, preserving gesture state.
        child: Listener(
          onPointerDown: (event) {
            // Select on mouse down (if not already selected)
            // Access selectedIds WITHOUT subscribing (using .value or internal check)
            if (!pc.selectedIds.contains(node.id)) {
              pc.selectedIds.assignOne(node.id);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) {
              pc.startDrag();
            },
            onPanUpdate: (details) {
              pc.moveSelection(Vec2(details.delta.dx, details.delta.dy));
            },
            onPanEnd: (_) {
              pc.endDrag();
            },
            // 3. Inner Scope: Visuals (Selection & Color)
            // Rebuilds cheaply on selection/color change without breaking gestures.
            child: LWatch(() {
              final isSelected = pc.selectedIds.contains(node.id);
              final color = node.color.value;

              return AnimatedScale(
                scale: isSelected ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: size.x,
                  height: size.y,
                  decoration: BoxDecoration(
                    color: Color(color),
                    borderRadius: node.type == 'circle'
                        ? BorderRadius.circular(size.x / 2)
                        : BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      );
    });
  }
}

/// The sidebar displaying properties of selected nodes.
class PropertySidebar extends StatelessWidget {
  const PropertySidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = Levit.find<ProjectController>();

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B), // Slate 800
        border: Border(right: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROPERTIES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Color(0xFF64748B), // Slate 500
            ),
          ),
          const SizedBox(height: 32),
          LWatch(() {
            final count = pc.selectedIds.length;
            if (count == 0) {
              return const Text('Select a node to edit properties');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count elements selected',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                const Text('Quick Colors'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ColorButton(
                      color: const Color(0xFF818CF8),
                      value: 0xFF818CF8,
                    ),
                    _ColorButton(
                      color: const Color(0xFFF43F5E),
                      value: 0xFFF43F5E,
                    ),
                    _ColorButton(
                      color: const Color(0xFF10B981),
                      value: 0xFF10B981,
                    ),
                    _ColorButton(
                      color: const Color(0xFFF59E0B),
                      value: 0xFFF59E0B,
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final int value;
  const _ColorButton({required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    final pc = Levit.find<ProjectController>();
    return GestureDetector(
      onTap: () {
        Lx.batch(() {
          for (final node in pc.engine.nodes) {
            if (pc.selectedIds.contains(node.id)) {
              node.color.value = value;
            }
          }
        });
        pc.syncColors();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

/// Renders a grid pattern background.
class GridBackground extends StatelessWidget {
  const GridBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(child: CustomPaint(painter: GridPainter()));
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    const step = 40.0;

    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// Overlay displaying the cursors of other connected users.
class PresenceOverlay extends StatelessWidget {
  const PresenceOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final presence = Levit.find<PresenceController>();

    return LWatch(() {
      return Stack(
        children: presence.remoteUsers.values.map((user) {
          return LWatch(() {
            final pos = user.cursor.value;
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 100),
              left: pos.x,
              top: pos.y,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.navigation, color: Color(user.color), size: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Color(user.color),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          });
        }).toList(),
      );
    });
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final pc = Levit.find<ProjectController>();
    final auth = Levit.find<AuthController>();

    return Positioned(
      top: 24,
      left: 24,
      right: 24,
      child: LWatch(() {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  const Text(
                    'NEXUS STUDIO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 24),
                  _PillarBadge(
                    label: 'ISOMORPHIC',
                    color: Colors.orange.withValues(alpha: 0.2),
                  ),
                  _PillarBadge(
                    label: 'REAL-TIME',
                    color: Colors.green.withValues(alpha: 0.2),
                  ),
                  if (auth.canEdit) ...[
                    const SizedBox(width: 32),
                    const Text(
                      'Add Shape:',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon:
                          const Icon(Icons.crop_square, color: Colors.white70),
                      tooltip: 'Add Square',
                      onPressed: () => pc.addNode('rect'),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.circle_outlined,
                        color: Colors.white70,
                      ),
                      tooltip: 'Add Circle',
                      onPressed: () => pc.addNode('circle'),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.change_history,
                        color: Colors.white70,
                      ),
                      tooltip: 'Add Triangle',
                      onPressed: () => pc.addNode('triangle'),
                    ),
                  ],
                  const SizedBox(width: 24),
                  if (auth.canEdit) ...[
                    IconButton(
                      onPressed: () => _showStatsDialog(context),
                      icon: const Icon(Icons.bar_chart, size: 20),
                      tooltip: 'Stats (Scoped DI)',
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    onPressed: (auth.canEdit && pc.canUndo) ? pc.undo : null,
                    icon: const Icon(Icons.undo, size: 20),
                    tooltip: 'Undo',
                    color: Colors.white70,
                  ),
                  IconButton(
                    onPressed: (auth.canEdit && pc.canRedo) ? pc.redo : null,
                    icon: const Icon(Icons.redo, size: 20),
                    tooltip: 'Redo',
                    color: Colors.white70,
                  ),
                ],
              ),
              Row(
                children: [
                  LWatch(() {
                    final session = auth.session.value;
                    if (session == null) return const SizedBox();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: session.role == 'editor'
                                ? Colors.blueAccent
                                : Colors.white24,
                            child: Text(
                              session.email[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            session.email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: auth.logout,
                            icon: const Icon(Icons.logout, size: 14),
                            color: Colors.white38,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(width: 16),
                  // Showcase: Lx.select + LWatch (Pillar 6)
                  // Optimized rebuilds only when count changes
                  LWatch(() {
                    final count = pc.nodeCount.value;
                    return Text(
                      '$count Nodes',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }),
                  const SizedBox(width: 16),
                  // Showcase: LStatusBuilder (Pillar 6)
                  // Handles async status (loading, success, error) automatically
                  LStatusBuilder<String>(
                    source: pc.sessionTimer,
                    onSuccess: (time) => Text(
                      'Session: $time',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    onWaiting: () => const Text(
                      'Session: --:--',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    onIdle: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: pc.export,
                    icon: LWatch(() {
                      final status = pc.exportStatus.value?.status;
                      if (status is LxWaiting) {
                        return const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        );
                      }
                      return const Icon(Icons.cloud_upload);
                    }),
                    label: LWatch(() {
                      final status = pc.exportStatus.value?.status;
                      if (status is LxWaiting) {
                        return const Text('EXPORTING...');
                      }
                      if (status is LxSuccess<String>) {
                        return Text(
                          '${status.value.split('successfully').first}DONE',
                        );
                      }
                      if (status is LxError) return const Text('FAILED');
                      return const Text('EXPORT');
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ), // End of Row
        ); // End of SingleChildScrollView
      }),
    );
  }

  void _showStatsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => LScope<StatsController>(
        init: () => StatsController(),
        child: const _StatsDialog(),
      ),
    );
  }
}

/// Showcase: LView (Pillar 6)
/// Automatically finds [AuthController] and rebuilds on reactive changes.
class _LoginOverlay extends LView<AuthController> {
  const _LoginOverlay();

  @override
  Widget buildContent(BuildContext context, AuthController auth) {
    // LView.autoWatch is true by default, so we don't need LWatch here.
    if (auth.isAuthenticated) return const SizedBox.shrink();

    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person, size: 48, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const Text(
                'Nexus Studio',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Collaborative Design System',
                style: TextStyle(fontSize: 14, color: Colors.white54),
              ),
              const SizedBox(height: 32),
              _LoginButton(
                label: 'Login as Editor',
                email: 'admin@nexus.io',
                color: Colors.blueAccent,
                onPressed: () => auth.login('admin@nexus.io'),
              ),
              const SizedBox(height: 12),
              _LoginButton(
                label: 'Login as Viewer',
                email: 'guest@nexus.io',
                color: Colors.white24,
                onPressed: () => auth.login('viewer@nexus.io'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final String label;
  final String email;
  final Color color;
  final VoidCallback onPressed;

  const _LoginButton({
    required this.label,
    required this.email,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label),
      ),
    );
  }
}

class _PillarBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PillarBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
// =============================================================================
// Showcase: Scoped DI (Pillar 2 - Scoped)
// This controller only exists while the dialog is open.
// =============================================================================

class StatsController extends LevitController {
  @override
  void onInit() {
    super.onInit();
    debugPrint('StatsController Initialized');
  }

  @override
  void onClose() {
    debugPrint('StatsController Closed');
    super.onClose();
  }
}

class _StatsDialog extends StatelessWidget {
  const _StatsDialog();

  @override
  Widget build(BuildContext context) {
    // Access the scoped controller to verify it's registered
    context.levit.find<StatsController>();

    final pc = context.levit.find<ProjectController>();
    final presence = context.levit.find<PresenceController>();

    return AlertDialog(
      title: const Text('Project Stats'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LWatch(() {
            return ListTile(
              title: const Text('Total Nodes'),
              trailing: Text('${pc.engine.nodes.length}'),
            );
          }),
          LWatch(() {
            return ListTile(
              title: const Text('Active Users'),
              trailing: Text('${presence.remoteUsers.length}'),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
