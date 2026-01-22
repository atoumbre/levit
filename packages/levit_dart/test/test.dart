import 'dart:async';
import 'dart:math' as math;
import 'dart:math';

import 'package:levit_dart/levit_dart.dart';
import 'package:rxdart/rxdart.dart';

/// ------------------------------------------------------------
/// This example demonstrates:
/// - Turning a raw Stream into reactive state (.lx)
/// - Deriving state declaratively (LxComputed)
/// - Managing side effects with explicit, auto-disposed watches
/// - Doing all of the above in pure Dart (no Flutter, no framework glue)
/// ------------------------------------------------------------

// Simulate an external async data source (e.g. GPS updates)
final StreamController<(int, int)> locationStream =
    StreamController<(int, int)>.broadcast();

Future<void> simulateRandomWalk() async {
  var current = (100, 100);

  // Initial delay before first emission
  await Future.delayed(const Duration(seconds: 5));

  locationStream.add(current);

  for (int i = 0; i < 1000; i++) {
    await Future.delayed(const Duration(milliseconds: 100));

    final x = current.$1 + math.Random().nextInt(10) - 5;
    final y = current.$2 + math.Random().nextInt(10) - 5;
    current = (x, y);

    locationStream.add(current);
  }

  locationStream.close();
}

/// ------------------------------------------------------------
/// Controller: owns lifecycle, state, derived values, and effects
/// ------------------------------------------------------------
class LocationController extends LevitController {
  /// External stream converted into reactive state.
  /// No adapters, no special async handling — same model as local state.
  final location = locationStream.stream.lx;

  /// Internal mutable reactive collection
  final wayPoints = LxList<(int, int)>();

  /// Derived reactive value
  late final LxComputed<double> distance;

  /// Persist the current location as a waypoint.
  /// `requireValue` is safe here because this is only invoked
  /// when the location stream has produced a valid value.
  void addWayPoint() {
    final value = location.requireValue;
    print('Adding waypoint: $value');
    wayPoints.add(value);
  }

  @override
  Future<void> onInit() async {
    super.onInit();

    /// Declarative derived state.
    /// Automatically tracks `wayPoints` — no manual wiring.
    distance = (() {
      var total = 0.0;

      for (int i = 0; i < wayPoints.length - 1; i++) {
        final p1 = wayPoints[i];
        final p2 = wayPoints[i + 1];

        total += sqrt(
          pow(p2.$1 - p1.$1, 2) + pow(p2.$2 - p1.$2, 2),
        );
      }

      print('Computed distance: $total');
      return total;
    }).lx;

    /// Side effect:
    /// - sample location every second
    /// - persist it as a waypoint
    ///
    /// The watch is explicitly registered and automatically
    /// disposed with the controller lifecycle.
    autoDispose(
      LxWatch(
        location.transform(
          (s) => s.sampleTime(const Duration(seconds: 1)),
        ),
        (_) => addWayPoint(),
      ),
    );
  }
}

Future<void> main(List<String> args) async {
  print('Starting simulation...');

  simulateRandomWalk();

  /// Controller instantiation + lifecycle start
  final controller = LocationController()..onInit();

  /// Wait for the first position to be emitted
  await controller.location.wait;

  /// Observe derived state
  controller.distance.stream.listen((snapshot) {
    print('Total distance: ${snapshot}');
  });

  /// Observe mutable state
  controller.wayPoints.stream.listen((snapshot) {
    print('New waypoint: ${snapshot.last}');
  });
}
