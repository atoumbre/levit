import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../benchmark_config.dart';
import '../../benchmark_engine.dart';

class RapidMutationBenchmark extends Benchmark {
  @override
  String get name => 'Rapid State Mutation';

  @override
  String get description =>
      'Updates a state variable ${BenchmarkConfig.rapidMutationIterations} times with one listener active.';

  @override
  bool get isUI => false;

  @override
  BenchmarkImplementation createImplementation(Framework framework) {
    switch (framework) {
      case Framework.levit:
        return LevitRapidMutation();
      case Framework.vanilla:
        return VanillaRapidMutation();
      case Framework.getx:
        return GetXRapidMutation();
      case Framework.bloc:
        return BlocRapidMutation();
      case Framework.riverpod:
        return RiverpodRapidMutation();
    }
  }
}

// --- Levit ---
class LevitRapidMutation extends BenchmarkImplementation {
  late LxVar<int> counter;
  int expectedValue = 0;

  @override
  Future<void> setup() async {
    counter = LxVar(0);
    counter.addListener(() {});
    expectedValue = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.rapidMutationIterations; i++) {
      counter.value++;
    }
    expectedValue += BenchmarkConfig.rapidMutationIterations;
  }

  @override
  Future<void> verify() async {
    if (counter.value != expectedValue) {
      throw StateError(
          'Levit counter mismatch: expected $expectedValue, got ${counter.value}');
    }
  }

  @override
  Future<void> teardown() async {
    counter.close();
  }
}

// --- Vanilla ---
class VanillaRapidMutation extends BenchmarkImplementation {
  late ValueNotifier<int> counter;
  int expectedValue = 0;

  @override
  Future<void> setup() async {
    counter = ValueNotifier(0);
    counter.addListener(() {});
    expectedValue = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.rapidMutationIterations; i++) {
      counter.value++;
    }
    expectedValue += BenchmarkConfig.rapidMutationIterations;
  }

  @override
  Future<void> verify() async {
    if (counter.value != expectedValue) {
      throw StateError(
          'Vanilla counter mismatch: expected $expectedValue, got ${counter.value}');
    }
  }

  @override
  Future<void> teardown() async {
    counter.dispose();
  }
}

// --- GetX ---
class GetXRapidMutation extends BenchmarkImplementation {
  late RxInt counter;
  int expectedValue = 0;

  @override
  Future<void> setup() async {
    counter = 0.obs;
    counter.listen((_) {});
    expectedValue = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.rapidMutationIterations; i++) {
      counter.value++;
    }
    expectedValue += BenchmarkConfig.rapidMutationIterations;
  }

  @override
  Future<void> verify() async {
    if (counter.value != expectedValue) {
      throw StateError(
          'GetX counter mismatch: expected $expectedValue, got ${counter.value}');
    }
  }

  @override
  Future<void> teardown() async {
    counter.close();
  }
}

// --- BLoC ---
class _CounterCubit extends Cubit<int> {
  _CounterCubit() : super(0);
  void increment() => emit(state + 1);
}

class BlocRapidMutation extends BenchmarkImplementation {
  // ignore: library_private_types_in_public_api
  late _CounterCubit cubit;
  int expectedValue = 0;

  @override
  Future<void> setup() async {
    cubit = _CounterCubit();
    cubit.stream.listen((_) {});
    expectedValue = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.rapidMutationIterations; i++) {
      cubit.increment();
    }
    expectedValue += BenchmarkConfig.rapidMutationIterations;
  }

  @override
  Future<void> verify() async {
    if (cubit.state != expectedValue) {
      throw StateError(
          'BLoC counter mismatch: expected $expectedValue, got ${cubit.state}');
    }
  }

  @override
  Future<void> teardown() async {
    await cubit.close();
  }
}

// --- Riverpod ---
class RiverpodRapidMutation extends BenchmarkImplementation {
  late ProviderContainer container;
  late StateProvider<int> provider;
  int expectedValue = 0;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    provider = StateProvider((ref) => 0);
    container.listen(provider, (previous, next) {});
    expectedValue = 0;
  }

  @override
  Future<void> run() async {
    final notifier = container.read(provider.notifier);
    for (int i = 0; i < BenchmarkConfig.rapidMutationIterations; i++) {
      notifier.state++;
    }
    expectedValue += BenchmarkConfig.rapidMutationIterations;
  }

  @override
  Future<void> verify() async {
    final value = container.read(provider);
    if (value != expectedValue) {
      throw StateError(
          'Riverpod counter mismatch: expected $expectedValue, got $value');
    }
  }

  @override
  Future<void> teardown() async {
    container.dispose();
  }
}
