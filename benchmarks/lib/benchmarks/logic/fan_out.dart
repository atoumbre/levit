import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:rxdart/rxdart.dart' as rxdart;
import '../../benchmark_config.dart';
import '../../benchmark_engine.dart';

class FanOutBenchmark extends Benchmark {
  @override
  String get name => 'Fan Out Update';

  @override
  String get description =>
      'One source updates ${BenchmarkConfig.fanOutDependents} dependents. Measures broadcast overhead.';

  @override
  bool get isUI => false;

  @override
  BenchmarkImplementation createImplementation(Framework framework) {
    switch (framework) {
      case Framework.levit:
        return LevitFanOutBenchmark();
      case Framework.vanilla:
        return VanillaFanOutBenchmark();
      case Framework.getx:
        return GetXFanOutBenchmark();
      case Framework.bloc:
        return BlocFanOutBenchmark();
      case Framework.riverpod:
        return RiverpodFanOutBenchmark();
    }
  }
}

// --- Levit ---
class LevitFanOutBenchmark extends BenchmarkImplementation {
  late LxVar<int> source;
  final List<LxComputed<int>> dependents = [];
  int expectedSource = 0;

  @override
  Future<void> setup() async {
    source = LxVar(0);
    dependents.clear();
    for (int i = 0; i < BenchmarkConfig.fanOutDependents; i++) {
      // Create 1000 computeds that listen to source
      dependents.add(LxComputed(() => source.value + i));
    }
    // Ensure all are listening
    for (final dep in dependents) {
      dep.addListener(() {});
    }
    expectedSource = 0;
  }

  @override
  Future<void> run() async {
    // Update source once, which should trigger 1000 updates
    source.value++;
    expectedSource++;
    final lastValue = dependents.last.value;
    if (lastValue != expectedSource + BenchmarkConfig.fanOutDependents - 1) {
      throw StateError(
          'Levit fan-out mismatch: expected last=${expectedSource + BenchmarkConfig.fanOutDependents - 1}, got $lastValue');
    }
  }

  @override
  Future<void> verify() async {
    if (source.value != expectedSource) {
      throw StateError(
          'Levit fan-out source mismatch: expected $expectedSource, got ${source.value}');
    }
  }

  @override
  Future<void> teardown() async {
    for (final d in dependents) {
      d.close();
    }
    source.close();
  }
}

// --- Vanilla (ChangeNotifier) ---
class VanillaFanOutBenchmark extends BenchmarkImplementation {
  late ValueNotifier<int> source;
  final List<VoidCallback> listeners = [];
  final List<int> lastValues = [];
  int expectedSource = 0;

  @override
  Future<void> setup() async {
    source = ValueNotifier(0);
    listeners.clear();
    lastValues
      ..clear()
      ..addAll(List.filled(BenchmarkConfig.fanOutDependents, 0));
    for (int i = 0; i < BenchmarkConfig.fanOutDependents; i++) {
      void listener() {
        lastValues[i] = source.value + i;
      }

      listeners.add(listener);
      source.addListener(listener);
    }
    expectedSource = 0;
  }

  @override
  Future<void> run() async {
    source.value++;
    expectedSource++;
  }

  @override
  Future<void> verify() async {
    if (source.value != expectedSource ||
        lastValues.last !=
            expectedSource + BenchmarkConfig.fanOutDependents - 1) {
      throw StateError(
          'Vanilla fan-out mismatch: source=${source.value}, last=${lastValues.last}, expected=$expectedSource');
    }
  }

  @override
  Future<void> teardown() async {
    source.dispose();
  }
}

// --- GetX ---
class GetXFanOutBenchmark extends BenchmarkImplementation {
  late RxInt source;
  final List<StreamSubscription> workers = [];
  final List<int> lastValues = [];
  int expectedSource = 0;

  @override
  Future<void> setup() async {
    source = 0.obs;
    workers.clear();
    lastValues
      ..clear()
      ..addAll(List.filled(BenchmarkConfig.fanOutDependents, 0));
    for (int i = 0; i < BenchmarkConfig.fanOutDependents; i++) {
      // listen (isActive: true)
      workers.add(source.listen((val) {
        lastValues[i] = val + i;
      }));
    }
    expectedSource = 0;
  }

  @override
  Future<void> run() async {
    source.value++;
    expectedSource++;
    await Future.microtask(() {});
  }

  @override
  Future<void> verify() async {
    if (source.value != expectedSource ||
        lastValues.last !=
            expectedSource + BenchmarkConfig.fanOutDependents - 1) {
      throw StateError(
          'GetX fan-out mismatch: source=${source.value}, last=${lastValues.last}, expected=$expectedSource');
    }
  }

  @override
  Future<void> teardown() async {
    for (final w in workers) {
      w.cancel();
    }
  }
}

// --- Riverpod ---
class RiverpodFanOutBenchmark extends BenchmarkImplementation {
  late ProviderContainer container;
  final sourceProvider = StateProvider<int>((ref) => 0);
  final List<Provider<int>> dependents = [];
  int expectedSource = 0;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    dependents.clear();
    for (int i = 0; i < BenchmarkConfig.fanOutDependents; i++) {
      final p = Provider((ref) => ref.watch(sourceProvider) + i);
      dependents.add(p);
      // Keep alive by listening
      container.listen(p, (_, __) {});
    }
    expectedSource = 0;
  }

  @override
  Future<void> run() async {
    final notifier = container.read(sourceProvider.notifier);
    notifier.state++;
    expectedSource++;
  }

  @override
  Future<void> verify() async {
    final sourceValue = container.read(sourceProvider);
    final lastValue = container.read(dependents.last);
    if (sourceValue != expectedSource ||
        lastValue != expectedSource + BenchmarkConfig.fanOutDependents - 1) {
      throw StateError(
          'Riverpod fan-out mismatch: source=$sourceValue, last=$lastValue, expected=$expectedSource');
    }
  }

  @override
  Future<void> teardown() async {
    container.dispose();
  }
}

// --- BLoC (RxDart) ---
class BlocFanOutBenchmark extends BenchmarkImplementation {
  late rxdart.BehaviorSubject<int> source;
  final List<StreamSubscription> subs = [];
  final List<int> lastValues = [];
  int expectedSource = 0;

  @override
  Future<void> setup() async {
    source = rxdart.BehaviorSubject.seeded(0);
    subs.clear();
    lastValues
      ..clear()
      ..addAll(List.filled(BenchmarkConfig.fanOutDependents, 0));
    for (int i = 0; i < BenchmarkConfig.fanOutDependents; i++) {
      subs.add(source.listen((val) {
        lastValues[i] = val + i;
      }));
    }
    expectedSource = 0;
  }

  @override
  Future<void> run() async {
    source.add(source.value + 1);
    expectedSource++;
    await Future.microtask(() {});
  }

  @override
  Future<void> verify() async {
    if (source.value != expectedSource ||
        lastValues.last !=
            expectedSource + BenchmarkConfig.fanOutDependents - 1) {
      throw StateError(
          'BLoC fan-out mismatch: source=${source.value}, last=${lastValues.last}, expected=$expectedSource');
    }
  }

  @override
  Future<void> teardown() async {
    for (final s in subs) {
      s.cancel();
    }
    await source.close();
  }
}
