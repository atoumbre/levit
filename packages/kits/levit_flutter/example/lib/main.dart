import 'dart:math';

import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

/// Runs the `levit_flutter` example application.
void main() {
  // Link all LxVar and LxList to their parent controller
  // All LxVar and LxList will be automatically disposed when the parent controller is disposed
  Levit.enableAutoLinking();
  runApp(const MyApp());
}

/// Immutable configuration and reactive state for a single simulated circle.
class CircleData {
  /// A stable identifier for this circle.
  final String id;

  /// The display color for this circle.
  final Color color;

  /// The speed scalar used by the simulation.
  final double speed;

  // Reactive properties that the UI will "watch" via Animated widgets

  /// The current center position of the circle.
  late final LxVar<Offset> position;

  /// The current radius of the circle.
  late final LxVar<double> radius;

  /// Creates a circle with an initial position and radius.
  ///
  /// [id] is the circle identifier.
  /// [initialPosition] is the initial center position.
  /// [initialRadius] is the initial radius.
  /// [color] is the display color.
  /// [speed] is the simulation speed scalar.
  CircleData({
    required this.id,
    required Offset initialPosition,
    required double initialRadius,
    required this.color,
    required this.speed,
  }) {
    position = LxVar(initialPosition).named('pos_$id');
    radius = LxVar(initialRadius).named('rad_$id');
  }

  // Even with auto-linking enabled, we can still manually dispose of the LxVar and LxList
  // This is useful for cleaning up resources when the object is no longer needed

  /// Closes the reactive state owned by this circle.
  void dispose() {
    position.close();
    radius.close();
  }
}

/// A controller that simulates and renders a set of animated circles.
class CircleController extends LevitController
    with
        LevitLoopExecutionMixin,
        LevitLoopExecutionLifecycleMixin,
        LevitSelectionMixin<String> {
  /// The active circles in the simulation.
  final circles = LxList<CircleData>().named('circles');

  /// Whether the simulation is currently paused.
  final isSimulationPaused = LxVar(false).named('isSimulationPaused');

  final _random = Random();

  /// The current size of the canvas used for bounds checking.
  Size canvasSize = Size.zero;

  /// Initializes the controller and starts the simulation loops.
  @override
  void onInit() {
    super.onInit();
    autoDispose(circles);

    // 1. Spawning Loop
    loopEngine.startLoop('spawn', () async {
      if (canvasSize != Size.zero) {
        _spawnCircle();
      }
    }, delay: const Duration(milliseconds: 500));

    // 2. Path Generation Loop (like a location stream)
    // Every 500ms, we pick a new target for all circles.
    // The UI's AnimatedPositioned will interpolate to this new target.
    loopEngine.startLoop('path', () async {
      _updateCircleTargets();
    }, delay: const Duration(milliseconds: 500));

    // 3. Shrink Loop
    // Smoothly shrink radius
      loopEngine.startLoop('shrink', () async {
        _shrinkCircles();
      }, delay: const Duration(milliseconds: 100));
  }

  void _spawnCircle() {
    final id = 'c_${DateTime.now().microsecondsSinceEpoch}';
    final initialRadius = 50.0; //20.0 + _random.nextDouble() * 30.0;
    final initialPosition = Offset(
      _random.nextDouble() * canvasSize.width,
      _random.nextDouble() * canvasSize.height,
    );

    final circle = CircleData(
      id: id,
      initialPosition: initialPosition,
      initialRadius: initialRadius,
      color: Color.fromARGB(
        255,
        _random.nextInt(256),
        _random.nextInt(256),
        _random.nextInt(256),
      ),
      speed: 1.0,
    );

    circles.add(circle);
  }

  void _updateCircleTargets() {
    for (final circle in circles) {
      // Pick a new random target nearby (random walk)
      final offset = Offset(
        (_random.nextDouble() - 0.5) * 200,
        (_random.nextDouble() - 0.5) * 200,
      );

      var newPos = circle.position.value + offset;

      // Keep within bounds
      newPos = Offset(
        newPos.dx.clamp(0, canvasSize.width),
        newPos.dy.clamp(0, canvasSize.height),
      );

      circle.position.value = newPos;
    }
  }

  void _shrinkCircles() {
    final toRemove = <CircleData>[];
    for (final circle in circles) {
      circle.radius.value -= 1.0;
      if (circle.radius.value <= 0) {
        toRemove.add(circle);
      }
    }

    if (toRemove.isNotEmpty) {
      for (final c in toRemove) {
        deselect(c.id);
        c.dispose();
      }
      circles.removeWhere((c) => toRemove.contains(c));
    }
  }

  /// Updates [canvasSize] used by the simulation bounds.
  void updateCanvasSize(Size size) {
    canvasSize = size;
  }

  /// Pauses or resumes the simulation loops.
  void toggleSimulation() {
    isSimulationPaused.value = !isSimulationPaused.value;
    if (isSimulationPaused.value) {
      loopEngine.pauseAllServices();
    } else {
      loopEngine.resumeAllServices();
    }
  }

  /// Resumes all loop services unless the simulation is manually paused.
  void resumeAllServices({bool force = false}) {
    // If simulation is manually paused, do not auto-resume on app foreground
    if (isSimulationPaused.value) return;
    loopEngine.resumeAllServices(force: force);
  }
}

/// The root widget for the example application.
class MyApp extends StatelessWidget {
  /// Creates the root widget for the example application.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Levit Circle Stream Canvas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueAccent,
      ),
      home: const CircleCanvasPage(),
    );
  }
}

/// A page that displays an animated circle simulation driven by a controller.
class CircleCanvasPage extends LScopedView<CircleController> {
  /// Creates the circle canvas page.
  const CircleCanvasPage({super.key});

  /// Creates and registers the controller instance in the view scope.
  @override
  CircleController onConfigScope(LevitScope scope) {
    return scope.put(() => CircleController());
  }

  // True by default
  // Override if you want to manually manage rebuilds with LWatch
  /// Whether the view automatically rebuilds when reactive values change.
  @override
  bool get autoWatch => true;

  /// Builds the view widget tree.
  @override
  Widget buildView(BuildContext context, CircleController controller) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Levit Bubbles'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Text(
            'Selected: ${controller.selectionCount}',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(
              controller.isSimulationPaused.value
                  ? Icons.play_arrow
                  : Icons.pause,
            ),
            onPressed: () => controller.toggleSimulation(),
            tooltip: controller.isSimulationPaused.value
                ? 'Resume Simulation'
                : 'Pause Simulation',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.circles.clear(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          controller.updateCanvasSize(size);

          // LWatch need as we are in a builder
          return LWatch(
            () => Stack(
              children: [
                for (final circle in controller.circles)
                  _AnimatedCircle(key: ValueKey(circle.id), data: circle),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedCircle extends LView<CircleController> {
  final CircleData data;

  const _AnimatedCircle({super.key, required this.data});

  @override
  Widget buildView(BuildContext context, CircleController controller) {
    // We use AnimatedPositioned and AnimatedContainer for buttery smooth
    // transitions between the locations emitted by the controller.

    return AnimatedPositioned(
      duration: const Duration(
        milliseconds: 500,
      ), // Match controller pathLoop delay
      curve: Curves.easeInOutSine, // Smooth navigation-like movement
      left: data.position.value.dx - data.radius.value,
      top: data.position.value.dy - data.radius.value,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) =>
            Opacity(opacity: value, child: child),
        child: GestureDetector(
          onTap: () => controller.toggle(data.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: data.radius.value * 2,
            height: data.radius.value * 2,
            decoration: BoxDecoration(
              color: data.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: data.color.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: controller.isSelected(data.id)
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
                width: controller.isSelected(data.id) ? 4.0 : 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
