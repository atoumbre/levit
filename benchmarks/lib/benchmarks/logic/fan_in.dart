import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:rxdart/rxdart.dart' as rxdart;
import '../../benchmark_config.dart';
import '../../benchmark_engine.dart';

class FanInBenchmark extends Benchmark {
  @override
  String get name => 'Fan In Update';

  @override
  String get description =>
      '${BenchmarkConfig.fanInInputs} sources update 1 dependent. Measures dependency tracking overhead.';

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
  int expectedOutput = BenchmarkConfig.fanInInputs;

  @override
  Future<void> setup() async {
    inputs.clear();
    for (int i = 0; i < BenchmarkConfig.fanInInputs; i++) {
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
    expectedOutput = BenchmarkConfig.fanInInputs;
  }

  @override
  Future<void> run() async {
    // Update one input. This should trigger re-evaluation of output.
    inputs[0].value++;
    expectedOutput++;
  }

  @override
  Future<void> verify() async {
    if (output.value != expectedOutput) {
      throw StateError(
          'Levit fan-in mismatch: expected $expectedOutput, got ${output.value}');
    }
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
  int expectedOutput = BenchmarkConfig.fanInInputs;

  @override
  Future<void> setup() async {
    inputs.clear();
    cleanup.clear();
    for (int i = 0; i < BenchmarkConfig.fanInInputs; i++) {
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
    expectedOutput = BenchmarkConfig.fanInInputs;
  }

  @override
  Future<void> run() async {
    inputs[0].value++;
    expectedOutput++;
  }

  @override
  Future<void> verify() async {
    if (output.value != expectedOutput) {
      throw StateError(
          'Vanilla fan-in mismatch: expected $expectedOutput, got ${output.value}');
    }
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
  final List<StreamSubscription> subs = [];
  final RxInt sum = 0.obs;
  int expectedOutput = BenchmarkConfig.fanInInputs;

  @override
  Future<void> run() async {
    inputs[0].value++;
    expectedOutput++;
    await Future.microtask(() {});
  }

  @override
  Future<void> setup() async {
    inputs.clear();
    subs.clear();
    for (int i = 0; i < BenchmarkConfig.fanInInputs; i++) {
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
    sum.value = BenchmarkConfig.fanInInputs;
    expectedOutput = BenchmarkConfig.fanInInputs;
  }

  @override
  Future<void> verify() async {
    if (sum.value != expectedOutput) {
      throw StateError(
          'GetX fan-in mismatch: expected $expectedOutput, got ${sum.value}');
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
  int expectedOutput = BenchmarkConfig.fanInInputs;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    inputProviders.clear();
    for (int i = 0; i < BenchmarkConfig.fanInInputs; i++) {
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
    expectedOutput = BenchmarkConfig.fanInInputs;
  }

  @override
  Future<void> run() async {
    final notifier = container.read(inputProviders[0].notifier);
    notifier.state++;
    expectedOutput++;
  }

  @override
  Future<void> verify() async {
    final output = container.read(outputProvider);
    if (output != expectedOutput) {
      throw StateError(
          'Riverpod fan-in mismatch: expected $expectedOutput, got $output');
    }
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
  int latestOutput = BenchmarkConfig.fanInInputs;
  int expectedOutput = BenchmarkConfig.fanInInputs;

  @override
  Future<void> setup() async {
    inputs.clear();
    for (int i = 0; i < BenchmarkConfig.fanInInputs; i++) {
      inputs.add(rxdart.BehaviorSubject.seeded(1));
    }

    final output = rxdart.Rx.combineLatestList(inputs).map((list) {
      return list.fold(0, (a, b) => a + b);
    });

    sub = output.listen((value) {
      latestOutput = value;
    });
    expectedOutput = BenchmarkConfig.fanInInputs;
    latestOutput = BenchmarkConfig.fanInInputs;
  }

  @override
  Future<void> run() async {
    inputs[0].add(inputs[0].value + 1);
    expectedOutput++;
    await Future.microtask(() {});
  }

  @override
  Future<void> verify() async {
    if (latestOutput != expectedOutput) {
      throw StateError(
          'BLoC fan-in mismatch: expected $expectedOutput, got $latestOutput');
    }
  }

  @override
  Future<void> teardown() async {
    await sub.cancel();
    for (final i in inputs) {
      await i.close();
    }
  }
}
