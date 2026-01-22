import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../benchmark_engine.dart';

/// Benchmark for scoped DI lookup.
/// Tests pure DI resolution performance without widget context overhead.
class ScopedDIBenchmark extends Benchmark {
  @override
  String get name => 'Scoped DI Lookup';

  @override
  String get description => '1000 DI lookups. Tests DI resolution performance.';

  @override
  bool get isUI => false;

  @override
  BenchmarkImplementation createImplementation(Framework framework) {
    switch (framework) {
      case Framework.levit:
        return LevitScopedDIBenchmark();
      case Framework.vanilla:
        return VanillaScopedDIBenchmark();
      case Framework.getx:
        return GetXScopedDIBenchmark();
      case Framework.bloc:
        return BlocScopedDIBenchmark();
      case Framework.riverpod:
        return RiverpodScopedDIBenchmark();
    }
  }
}

// Service to look up
class CounterService {
  int value = 0;
  void increment() => value++;
}

// --- Levit ---
class LevitScopedDIBenchmark extends BenchmarkImplementation {
  @override
  Future<void> setup() async {
    Levit.put(() => CounterService());
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 1000; i++) {
      final service = Levit.find<CounterService>();
      service.increment();
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    Levit.delete<CounterService>();
  }
}

// --- Vanilla (Manual service locator) ---
class _ServiceLocator {
  final Map<Type, dynamic> _services = {};

  void register<T>(T service) {
    _services[T] = service;
  }

  T find<T>() {
    return _services[T] as T;
  }

  void remove<T>() {
    _services.remove(T);
  }
}

class VanillaScopedDIBenchmark extends BenchmarkImplementation {
  final _locator = _ServiceLocator();

  @override
  Future<void> setup() async {
    _locator.register(CounterService());
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 1000; i++) {
      final service = _locator.find<CounterService>();
      service.increment();
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    _locator.remove<CounterService>();
  }
}

// --- GetX ---
class GetXScopedDIBenchmark extends BenchmarkImplementation {
  @override
  Future<void> setup() async {
    Get.put(CounterService());
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 1000; i++) {
      final service = Get.find<CounterService>();
      service.increment();
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    Get.delete<CounterService>();
  }
}

// --- Riverpod ---
final _counterProvider = Provider<CounterService>((ref) => CounterService());

class RiverpodScopedDIBenchmark extends BenchmarkImplementation {
  late ProviderContainer container;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 1000; i++) {
      final service = container.read(_counterProvider);
      service.increment();
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    container.dispose();
  }
}

// --- BLoC (using get_it pattern) ---
class _BlocServiceLocator {
  final Map<Type, dynamic> _services = {};

  void register<T>(T service) {
    _services[T] = service;
  }

  T get<T>() {
    return _services[T] as T;
  }

  void unregister<T>() {
    _services.remove(T);
  }
}

class BlocScopedDIBenchmark extends BenchmarkImplementation {
  final _locator = _BlocServiceLocator();

  @override
  Future<void> setup() async {
    _locator.register(CounterService());
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 1000; i++) {
      final service = _locator.get<CounterService>();
      service.increment();
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    _locator.unregister<CounterService>();
  }
}
