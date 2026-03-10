import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../benchmark_config.dart';
import '../../benchmark_engine.dart';

/// Benchmark for scoped DI lookup.
/// Tests pure DI resolution performance without widget context overhead.
class ScopedDIBenchmark extends Benchmark {
  @override
  String get name => 'Scoped DI Lookup';

  @override
  String get description =>
      '${BenchmarkConfig.scopedDiIterations} DI lookups. Tests DI resolution performance.';

  @override
  bool get isUI => false;

  @override
  BenchmarkClassification get classification =>
      BenchmarkClassification.featureDemo;

  @override
  String get comparisonNote =>
      'DI containers are not first-class primitives in every framework.';

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
  int expectedValue = 0;

  @override
  Future<void> setup() async {
    Levit.put(() => CounterService());
    expectedValue = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.scopedDiIterations; i++) {
      final service = Levit.find<CounterService>();
      service.increment();
    }
    expectedValue += BenchmarkConfig.scopedDiIterations;
  }

  @override
  Future<void> verify() async {
    final service = Levit.find<CounterService>();
    if (service.value != expectedValue) {
      throw StateError(
          'Levit DI mismatch: expected $expectedValue, got ${service.value}');
    }
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
  int expectedValue = 0;

  @override
  Future<void> setup() async {
    _locator.register(CounterService());
    expectedValue = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.scopedDiIterations; i++) {
      final service = _locator.find<CounterService>();
      service.increment();
    }
    expectedValue += BenchmarkConfig.scopedDiIterations;
  }

  @override
  Future<void> verify() async {
    final service = _locator.find<CounterService>();
    if (service.value != expectedValue) {
      throw StateError(
          'Vanilla DI mismatch: expected $expectedValue, got ${service.value}');
    }
  }

  @override
  Future<void> teardown() async {
    _locator.remove<CounterService>();
  }
}

// --- GetX ---
class GetXScopedDIBenchmark extends BenchmarkImplementation {
  int expectedValue = 0;

  @override
  Future<void> setup() async {
    Get.put(CounterService());
    expectedValue = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.scopedDiIterations; i++) {
      final service = Get.find<CounterService>();
      service.increment();
    }
    expectedValue += BenchmarkConfig.scopedDiIterations;
  }

  @override
  Future<void> verify() async {
    final service = Get.find<CounterService>();
    if (service.value != expectedValue) {
      throw StateError(
          'GetX DI mismatch: expected $expectedValue, got ${service.value}');
    }
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
  int expectedValue = 0;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    expectedValue = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.scopedDiIterations; i++) {
      final service = container.read(_counterProvider);
      service.increment();
    }
    expectedValue += BenchmarkConfig.scopedDiIterations;
  }

  @override
  Future<void> verify() async {
    final service = container.read(_counterProvider);
    if (service.value != expectedValue) {
      throw StateError(
          'Riverpod DI mismatch: expected $expectedValue, got ${service.value}');
    }
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
  int expectedValue = 0;

  @override
  Future<void> setup() async {
    _locator.register(CounterService());
    expectedValue = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.scopedDiIterations; i++) {
      final service = _locator.get<CounterService>();
      service.increment();
    }
    expectedValue += BenchmarkConfig.scopedDiIterations;
  }

  @override
  Future<void> verify() async {
    final service = _locator.get<CounterService>();
    if (service.value != expectedValue) {
      throw StateError(
          'BLoC DI mismatch: expected $expectedValue, got ${service.value}');
    }
  }

  @override
  Future<void> teardown() async {
    _locator.unregister<CounterService>();
  }
}
