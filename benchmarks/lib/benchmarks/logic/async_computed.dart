import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart' as rxdart;
import '../../benchmark_engine.dart';

/// Benchmark for async computed values.
/// Tests frameworks' ability to handle async dependency tracking.
class AsyncComputedBenchmark extends Benchmark {
  @override
  String get name => 'Async Computed';

  @override
  String get description =>
      'Async computed that re-fetches on 100 source changes. Tests async tracking.';

  @override
  bool get isUI => false;

  @override
  BenchmarkImplementation createImplementation(Framework framework) {
    switch (framework) {
      case Framework.levit:
        return LevitAsyncComputedBenchmark();
      case Framework.vanilla:
        return VanillaAsyncComputedBenchmark();
      case Framework.getx:
        return GetXAsyncComputedBenchmark();
      case Framework.bloc:
        return BlocAsyncComputedBenchmark();
      case Framework.riverpod:
        return RiverpodAsyncComputedBenchmark();
    }
  }
}

// --- Levit ---
class LevitAsyncComputedBenchmark extends BenchmarkImplementation {
  late LxVar<int> source;
  late LxAsyncComputed<String> asyncComputed;
  late VoidCallback listener;

  @override
  Future<void> setup() async {
    source = LxVar(0);
    asyncComputed = LxComputed.async(() async {
      final val = source.value;
      // Simulate async operation
      await Future.delayed(const Duration(microseconds: 1));
      return 'Result: $val';
    });

    listener = () {};
    asyncComputed.addListener(listener);
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 100; i++) {
      source.value++;
      // Wait for async to complete
      await Future.delayed(const Duration(microseconds: 10));
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    asyncComputed.removeListener(listener);
    asyncComputed.close();
    source.close();
  }
}

// --- Vanilla (ValueNotifier with async listener) ---
class VanillaAsyncComputedBenchmark extends BenchmarkImplementation {
  late ValueNotifier<int> source;
  late ValueNotifier<String> result;
  bool _isProcessing = false;

  @override
  Future<void> setup() async {
    source = ValueNotifier(0);
    result = ValueNotifier('Result: 0');

    // Async listener that updates result
    source.addListener(() async {
      if (_isProcessing) return;
      _isProcessing = true;
      final val = source.value;
      await Future.delayed(const Duration(microseconds: 1));
      result.value = 'Result: $val';
      _isProcessing = false;
    });
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 100; i++) {
      source.value++;
      await Future.delayed(const Duration(microseconds: 10));
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    source.dispose();
    result.dispose();
  }
}

// --- GetX (RxInt with async transformation) ---
class GetXAsyncComputedBenchmark extends BenchmarkImplementation {
  late RxInt source;
  late Rx<String> result;
  late StreamSubscription sub;

  @override
  Future<void> setup() async {
    source = 0.obs;
    result = 'Result: 0'.obs;

    // Use stream transformation for async computed
    sub = source.stream.asyncMap((val) async {
      await Future.delayed(const Duration(microseconds: 1));
      return 'Result: $val';
    }).listen((value) {
      result.value = value;
    });
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 100; i++) {
      source.value++;
      await Future.delayed(const Duration(microseconds: 10));
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    await sub.cancel();
    source.close();
    result.close();
  }
}

// --- Riverpod ---
class RiverpodAsyncComputedBenchmark extends BenchmarkImplementation {
  late ProviderContainer container;
  final sourceProvider = StateProvider<int>((ref) => 0);
  late FutureProvider<String> asyncProvider;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    asyncProvider = FutureProvider<String>((ref) async {
      final val = ref.watch(sourceProvider);
      await Future.delayed(const Duration(microseconds: 1));
      return 'Result: $val';
    });
    container.listen(asyncProvider, (_, __) {});
  }

  @override
  Future<int> run() async {
    final notifier = container.read(sourceProvider.notifier);
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 100; i++) {
      notifier.state++;
      await Future.delayed(const Duration(microseconds: 10));
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    container.dispose();
  }
}

// --- BLoC (RxDart with async transformation) ---
class BlocAsyncComputedBenchmark extends BenchmarkImplementation {
  late rxdart.BehaviorSubject<int> source;
  late Stream<String> result;
  late StreamSubscription sub;

  @override
  Future<void> setup() async {
    source = rxdart.BehaviorSubject.seeded(0);

    // Async transformation using asyncMap
    result = source.asyncMap((val) async {
      await Future.delayed(const Duration(microseconds: 1));
      return 'Result: $val';
    });

    sub = result.listen((_) {});
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 100; i++) {
      source.add(source.value + 1);
      await Future.delayed(const Duration(microseconds: 10));
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    await sub.cancel();
    await source.close();
  }
}
