import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levit_reactive/levit_reactive.dart';
import '../../benchmark_engine.dart';

/// Benchmark comparing batched vs un-batched updates.
/// Demonstrates the value of Lx.batch() for bulk operations.
class BatchVsUnBatchedBenchmark extends Benchmark {
  @override
  String get name => 'Batch vs Un-batched';

  @override
  String get description =>
      '1000 updates with batching. Tests batch efficiency.';

  @override
  bool get isUI => false;

  @override
  BenchmarkImplementation createImplementation(Framework framework) {
    switch (framework) {
      case Framework.levit:
        return LevitBatchBenchmark();
      case Framework.vanilla:
        return VanillaBatchBenchmark();
      case Framework.getx:
        return GetXBatchBenchmark();
      case Framework.bloc:
        return BlocBatchBenchmark();
      case Framework.riverpod:
        return RiverpodBatchBenchmark();
    }
  }
}

// --- Levit ---
class LevitBatchBenchmark extends BenchmarkImplementation {
  final List<LxVar<int>> sources = [];
  late LxComputed<int> sum;
  late VoidCallback listener;
  int notifyCount = 0;

  @override
  Future<void> setup() async {
    sources.clear();
    notifyCount = 0;
    for (int i = 0; i < 100; i++) {
      sources.add(LxVar(0));
    }
    sum = LxComputed(() {
      int total = 0;
      for (final s in sources) {
        total += s.value;
      }
      return total;
    });
    listener = () => notifyCount++;
    sum.addListener(listener);
  }

  @override
  Future<int> run() async {
    notifyCount = 0;
    final stopwatch = Stopwatch()..start();

    // Batched: Should trigger only 1 notification
    Lx.batch(() {
      for (int i = 0; i < 1000; i++) {
        sources[i % 100].value++;
      }
    });

    await Future.microtask(() {});
    stopwatch.stop();

    // Verify batching worked (should be 1, not 1000)
    // print('Levit notify count: $notifyCount');

    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    sum.removeListener(listener);
    sum.close();
    for (final s in sources) {
      s.close();
    }
  }
}

// --- Vanilla (no batching available) ---
class VanillaBatchBenchmark extends BenchmarkImplementation {
  final List<ValueNotifier<int>> sources = [];
  int sum = 0;
  int notifyCount = 0;

  @override
  Future<void> setup() async {
    sources.clear();
    notifyCount = 0;
    for (int i = 0; i < 100; i++) {
      final notifier = ValueNotifier(0);
      sources.add(notifier);
    }

    void updateSum() {
      notifyCount++;
      int total = 0;
      for (final s in sources) {
        total += s.value;
      }
      sum = total;
    }

    for (final s in sources) {
      s.addListener(updateSum);
    }
  }

  @override
  Future<int> run() async {
    notifyCount = 0;
    final stopwatch = Stopwatch()..start();

    // No batching - will trigger many notifications
    for (int i = 0; i < 1000; i++) {
      sources[i % 100].value++;
    }

    await Future.microtask(() {});
    stopwatch.stop();

    // print('Vanilla notify count: $notifyCount');

    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    for (final s in sources) {
      s.dispose();
    }
  }
}

// --- GetX ---
class GetXBatchBenchmark extends BenchmarkImplementation {
  final List<RxInt> sources = [];
  int notifyCount = 0;
  final subs = <StreamSubscription>[];

  @override
  Future<void> setup() async {
    sources.clear();
    subs.clear();
    notifyCount = 0;
    for (int i = 0; i < 100; i++) {
      sources.add(0.obs);
    }

    for (final s in sources) {
      subs.add(s.listen((_) => notifyCount++));
    }
  }

  @override
  Future<int> run() async {
    notifyCount = 0;
    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < 1000; i++) {
      sources[i % 100].value++;
    }

    await Future.microtask(() {});
    stopwatch.stop();

    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    for (final s in subs) {
      s.cancel();
    }
  }
}

// --- Riverpod ---
class RiverpodBatchBenchmark extends BenchmarkImplementation {
  late ProviderContainer container;
  final List<StateProvider<int>> providers = [];
  int notifyCount = 0;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    providers.clear();
    notifyCount = 0;

    for (int i = 0; i < 100; i++) {
      final p = StateProvider<int>((ref) => 0);
      providers.add(p);
      container.listen(p, (_, __) => notifyCount++);
    }
  }

  @override
  Future<int> run() async {
    notifyCount = 0;
    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < 1000; i++) {
      container.read(providers[i % 100].notifier).state++;
    }

    await Future.microtask(() {});
    stopwatch.stop();

    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    container.dispose();
  }
}

// --- BLoC ---
class BlocBatchBenchmark extends BenchmarkImplementation {
  final List<ValueNotifier<int>> sources = [];
  int notifyCount = 0;

  @override
  Future<void> setup() async {
    sources.clear();
    notifyCount = 0;
    for (int i = 0; i < 100; i++) {
      final notifier = ValueNotifier(0);
      notifier.addListener(() => notifyCount++);
      sources.add(notifier);
    }
  }

  @override
  Future<int> run() async {
    notifyCount = 0;
    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < 1000; i++) {
      sources[i % 100].value++;
    }

    await Future.microtask(() {});
    stopwatch.stop();

    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    for (final s in sources) {
      s.dispose();
    }
  }
}
