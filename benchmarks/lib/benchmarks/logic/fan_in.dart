import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levit_reactive/levit_reactive.dart';
import '../../benchmark_engine.dart';
import 'package:rxdart/rxdart.dart' as rxdart;

class FanInBenchmark extends Benchmark {
  @override
  String get name => 'Fan In Update';

  @override
  String get description =>
      '1000 sources update 1 dependent. Measures dependency tracking overhead.';

  @override
  bool get isUI => false;

  @override
  BenchmarkImplementation createImplementation(Framework framework) {
    switch (framework) {
      case Framework.levit:
        return LevitFanInBenchmark();
      case Framework.vanilla:
        return VanillaFanInBenchmark();
      case Framework.getx:
        return GetXFanInBenchmark();
      case Framework.bloc:
        return BlocFanInBenchmark();
      case Framework.riverpod:
        return RiverpodFanInBenchmark();
    }
  }
}

// --- Levit ---
class LevitFanInBenchmark extends BenchmarkImplementation {
  final List<LxVar<int>> inputs = [];
  late LxComputed<int> output;
  late VoidCallback listener;

  @override
  Future<void> setup() async {
    inputs.clear();
    for (int i = 0; i < 1000; i++) {
      inputs.add(LxVar(1));
    }

    // Create one computed that depends on all 1000 inputs
    output = LxComputed(() {
      int sum = 0;
      for (final input in inputs) {
        sum += input.value;
      }
      return sum;
    });

    // Keep it active
    listener = () {};
    output.addListener(listener);
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    // Update one input. This should trigger re-evaluation of output.
    inputs[0].value++;
    await Future.microtask(() {});
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    output.removeListener(listener);
    output.close();
    for (final input in inputs) {
      input.close();
    }
  }
}

// --- Vanilla (ChangeNotifier) ---
class VanillaFanInBenchmark extends BenchmarkImplementation {
  final List<ValueNotifier<int>> inputs = [];
  late ValueNotifier<int> output;
  final List<VoidCallback> cleanup = [];

  @override
  Future<void> setup() async {
    inputs.clear();
    cleanup.clear();
    for (int i = 0; i < 1000; i++) {
      inputs.add(ValueNotifier(1));
    }

    output = ValueNotifier(1000);

    void update() {
      int sum = 0;
      for (final input in inputs) {
        sum += input.value;
      }
      output.value = sum;
    }

    // output depends on all inputs
    // In Vanilla, we must manually listen to all
    for (final input in inputs) {
      input.addListener(update);
      cleanup.add(() => input.removeListener(update));
    }
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    inputs[0].value++;
    await Future.microtask(() {});
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    for (final fn in cleanup) {
      fn();
    }
    for (final i in inputs) {
      i.dispose();
    }
    output.dispose();
  }
}

// --- GetX ---
class GetXFanInBenchmark extends BenchmarkImplementation {
  final List<RxInt> inputs = [];
  late RxInt output;
  StreamSubscription? worker;
  final List<StreamSubscription> subs = [];
  final RxInt sum = 0.obs;

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    inputs[0].value++;
    await Future.microtask(() {});
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> setup() async {
    inputs.clear();
    subs.clear();
    for (int i = 0; i < 1000; i++) {
      inputs.add(1.obs);
    }

    void update() {
      int val = 0;
      for (final i in inputs) {
        val += i.value;
      }
      sum.value = val;
    }

    for (final i in inputs) {
      subs.add(i.listen((_) => update()));
    }
  }

  @override
  Future<void> teardown() async {
    for (final s in subs) {
      s.cancel();
    }
  }
}

// --- Riverpod ---
class RiverpodFanInBenchmark extends BenchmarkImplementation {
  late ProviderContainer container;
  final List<StateProvider<int>> inputProviders = [];
  late Provider<int> outputProvider;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    inputProviders.clear();
    for (int i = 0; i < 1000; i++) {
      inputProviders.add(StateProvider((ref) => 1));
    }

    outputProvider = Provider((ref) {
      int sum = 0;
      for (final p in inputProviders) {
        sum += ref.watch(p);
      }
      return sum;
    });

    // Keep alive
    container.listen(outputProvider, (_, __) {});
  }

  @override
  Future<int> run() async {
    final notifier = container.read(inputProviders[0].notifier);
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
class BlocFanInBenchmark extends BenchmarkImplementation {
  final List<rxdart.BehaviorSubject<int>> inputs = [];
  late StreamSubscription sub;

  @override
  Future<void> setup() async {
    inputs.clear();
    for (int i = 0; i < 1000; i++) {
      inputs.add(rxdart.BehaviorSubject.seeded(1));
    }

    final output = rxdart.Rx.combineLatestList(inputs).map((list) {
      return list.fold(0, (a, b) => a + b);
    });

    sub = output.listen((_) {});
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    inputs[0].add(inputs[0].value + 1);
    await Future.microtask(() {});
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    await sub.cancel();
    for (final i in inputs) {
      await i.close();
    }
  }
}
