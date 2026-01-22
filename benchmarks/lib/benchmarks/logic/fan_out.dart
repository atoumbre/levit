import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levit_reactive/levit_reactive.dart';
import '../../benchmark_engine.dart';
import 'package:rxdart/rxdart.dart' as rxdart;

class FanOutBenchmark extends Benchmark {
  @override
  String get name => 'Fan Out Update';

  @override
  String get description =>
      'One source updates 1000 dependents. Measures broadcast overhead.';

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

  @override
  Future<void> setup() async {
    source = LxVar(0);
    dependents.clear();
    for (int i = 0; i < 1000; i++) {
      // Create 1000 computeds that listen to source
      dependents.add(LxComputed(() => source.value + i));
    }
    // Ensure all are listening
    for (final dep in dependents) {
      dep.addListener(() {});
    }
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    // Update source once, which should trigger 1000 updates
    source.value++;
    // Flush microtasks to ensure all synchronous notifications complete
    await Future.microtask(() {});
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
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

  @override
  Future<void> setup() async {
    source = ValueNotifier(0);
    listeners.clear();
    for (int i = 0; i < 1000; i++) {
      void listener() {
        final _ = source.value + i;
      }

      listeners.add(listener);
      source.addListener(listener);
    }
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    source.value++;
    await Future.microtask(() {});
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
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

  @override
  Future<void> setup() async {
    source = 0.obs;
    workers.clear();
    for (int i = 0; i < 1000; i++) {
      // listen (isActive: true)
      workers.add(source.listen((val) {
        final _ = val + i;
      }));
    }
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    source.value++;
    await Future.microtask(() {});
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
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

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    dependents.clear();
    for (int i = 0; i < 1000; i++) {
      final p = Provider((ref) => ref.watch(sourceProvider) + i);
      dependents.add(p);
      // Keep alive by listening
      container.listen(p, (_, __) {});
    }
  }

  @override
  Future<int> run() async {
    final notifier = container.read(sourceProvider.notifier);
    final stopwatch = Stopwatch()..start();
    notifier.state++;
    await Future.microtask(() {});
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
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

  @override
  Future<void> setup() async {
    source = rxdart.BehaviorSubject.seeded(0);
    subs.clear();
    for (int i = 0; i < 1000; i++) {
      subs.add(source.listen((val) {
        final _ = val + i;
      }));
    }
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    source.add(source.value + 1);
    await Future.microtask(() {});
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    for (final s in subs) {
      s.cancel();
    }
    await source.close();
  }
}
