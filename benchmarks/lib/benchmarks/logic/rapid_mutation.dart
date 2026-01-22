import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levit_reactive/levit_reactive.dart';
import '../../benchmark_engine.dart';

class RapidMutationBenchmark extends Benchmark {
  @override
  String get name => 'Rapid State Mutation';

  @override
  String get description =>
      'Updates a state variable 1,000,000 times with one listener active.';

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

  @override
  Future<void> setup() async {
    counter = LxVar(0);
    counter.addListener(() {});
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 1000000; i++) {
      counter.value++;
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    counter.close();
  }
}

// --- Vanilla ---
class VanillaRapidMutation extends BenchmarkImplementation {
  late ValueNotifier<int> counter;

  @override
  Future<void> setup() async {
    counter = ValueNotifier(0);
    counter.addListener(() {});
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 1000000; i++) {
      counter.value++;
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    counter.dispose();
  }
}

// --- GetX ---
class GetXRapidMutation extends BenchmarkImplementation {
  late RxInt counter;

  @override
  Future<void> setup() async {
    counter = 0.obs;
    counter.listen((_) {});
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 1000000; i++) {
      counter.value++;
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
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

  @override
  Future<void> setup() async {
    cubit = _CounterCubit();
    cubit.stream.listen((_) {});
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 1000000; i++) {
      cubit.increment();
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
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

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    provider = StateProvider((ref) => 0);
    container.listen(provider, (previous, next) {});
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    final notifier = container.read(provider.notifier);
    for (int i = 0; i < 1000000; i++) {
      notifier.state++;
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    container.dispose();
  }
}
