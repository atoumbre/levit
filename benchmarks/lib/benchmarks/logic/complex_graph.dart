import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../benchmark_config.dart';
import '../../benchmark_engine.dart';
import 'package:rxdart/rxdart.dart' as rxdart;

class ComplexGraphBenchmark extends Benchmark {
  @override
  String get name => 'Complex Graph (Diamond)';

  @override
  String get description =>
      'A updates B and C; D depends on B and C. Measures overhead of diamond dependency.';

  @override
  bool get isUI => false;

  @override
  BenchmarkClassification get classification =>
      BenchmarkClassification.approximate;

  @override
  String get comparisonNote =>
      'Uses each framework\'s closest graph/computed primitive.';

  @override
  BenchmarkImplementation createImplementation(Framework framework) {
    switch (framework) {
      case Framework.levit:
        return LevitGraphBenchmark();
      case Framework.vanilla:
        return VanillaGraphBenchmark();
      case Framework.getx:
        return GetXGraphBenchmark();
      case Framework.bloc:
        return BlocGraphBenchmark();
      case Framework.riverpod:
        return RiverpodGraphBenchmark();
    }
  }
}

// --- Levit ---
class LevitGraphBenchmark extends BenchmarkImplementation {
  late LxVar<int> a;
  late LxComputed<int> b;
  late LxComputed<int> c;
  late LxComputed<int> d;
  late VoidCallback listener;
  int expectedA = 0;

  @override
  Future<void> setup() async {
    a = LxVar(0);
    // Use synchronous LxComputed for fair comparison, with staticDeps optimization
    b = LxComputed(() => a.value + 1, staticDeps: true);
    c = LxComputed(() => a.value * 2, staticDeps: true);
    // Access .computedValue to get the actual int value
    d = LxComputed(() => b.value + c.value, staticDeps: true);

    listener = () {};
    d.addListener(listener);
    expectedA = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.complexGraphIterations; i++) {
      a.value++;
    }
    expectedA += BenchmarkConfig.complexGraphIterations;
    final value = d.value;
    if (value != _expectedOutput(expectedA)) {
      throw StateError(
          'Levit graph mismatch: expected ${_expectedOutput(expectedA)}, got $value');
    }
  }

  @override
  Future<void> verify() async {
    if (a.value != expectedA || d.value != _expectedOutput(expectedA)) {
      throw StateError(
          'Levit graph verification failed: a=${a.value}, d=${d.value}, expectedA=$expectedA');
    }
  }

  @override
  Future<void> teardown() async {
    d.removeListener(listener);
    a.close();
    b.close();
    c.close();
    d.close();
  }
}

// --- Vanilla (Manual Listeners) ---
class VanillaGraphBenchmark extends BenchmarkImplementation {
  late ValueNotifier<int> a;
  late ValueNotifier<int> b;
  late ValueNotifier<int> c;
  late ValueNotifier<int> d;
  late VoidCallback updateB;
  late VoidCallback updateC;
  late VoidCallback updateD;
  int expectedA = 0;

  @override
  Future<void> setup() async {
    a = ValueNotifier(0);
    b = ValueNotifier(1);
    c = ValueNotifier(0);
    d = ValueNotifier(1);

    updateB = () {
      b.value = a.value + 1;
    };
    updateC = () {
      c.value = a.value * 2;
    };
    updateD = () {
      d.value = b.value + c.value;
    };

    a.addListener(updateB);
    a.addListener(updateC);
    b.addListener(updateD);
    c.addListener(updateD);
    expectedA = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.complexGraphIterations; i++) {
      a.value++;
    }
    expectedA += BenchmarkConfig.complexGraphIterations;
    if (d.value != _expectedOutput(expectedA)) {
      throw StateError(
          'Vanilla graph mismatch: expected ${_expectedOutput(expectedA)}, got ${d.value}');
    }
  }

  @override
  Future<void> verify() async {
    if (a.value != expectedA || d.value != _expectedOutput(expectedA)) {
      throw StateError(
          'Vanilla graph verification failed: a=${a.value}, d=${d.value}, expectedA=$expectedA');
    }
  }

  @override
  Future<void> teardown() async {
    a.removeListener(updateB);
    a.removeListener(updateC);
    b.removeListener(updateD);
    c.removeListener(updateD);
    a.dispose();
    b.dispose();
    c.dispose();
    d.dispose();
  }
}

// --- GetX ---
class GetXGraphBenchmark extends BenchmarkImplementation {
  late RxInt a;
  late RxInt bVal;
  late RxInt cVal;
  late RxInt dVal;
  late StreamSubscription subA1;
  late StreamSubscription subA2;
  late StreamSubscription subB;
  late StreamSubscription subC;
  int expectedA = 0;

  @override
  Future<void> setup() async {
    a = 0.obs;
    bVal = 1.obs;
    cVal = 0.obs;
    dVal = 1.obs;

    // Fixed: Separate listeners to prevent duplicate updates
    subA1 = a.listen((val) {
      bVal.value = val + 1;
    });

    subA2 = a.listen((val) {
      cVal.value = val * 2;
    });

    // Use a flag to prevent duplicate D updates within same cycle
    bool updatingD = false;
    void updateD() {
      if (updatingD) return;
      updatingD = true;
      Future.microtask(() {
        dVal.value = bVal.value + cVal.value;
        updatingD = false;
      });
    }

    subB = bVal.listen((val) => updateD());
    subC = cVal.listen((val) => updateD());
    expectedA = 0;
    dVal.value = _expectedOutput(expectedA);
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.complexGraphIterations; i++) {
      a.value++;
    }
    expectedA += BenchmarkConfig.complexGraphIterations;
    await _waitForValue(
      current: () => dVal.value,
      expected: _expectedOutput(expectedA),
      label: 'GetX graph',
    );
  }

  @override
  Future<void> verify() async {
    if (a.value != expectedA || dVal.value != _expectedOutput(expectedA)) {
      throw StateError(
          'GetX graph verification failed: a=${a.value}, d=${dVal.value}, expectedA=$expectedA');
    }
  }

  @override
  Future<void> teardown() async {
    await subA1.cancel();
    await subA2.cancel();
    await subB.cancel();
    await subC.cancel();
  }
}

// --- Riverpod ---
class RiverpodGraphBenchmark extends BenchmarkImplementation {
  late ProviderContainer container;

  final aProvider = StateProvider<int>((ref) => 0);
  late Provider<int> bProvider;
  late Provider<int> cProvider;
  late Provider<int> dProvider;
  int expectedA = 0;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    bProvider = Provider((ref) => ref.watch(aProvider) + 1);
    cProvider = Provider((ref) => ref.watch(aProvider) * 2);
    dProvider = Provider((ref) => ref.watch(bProvider) + ref.watch(cProvider));

    container.listen(dProvider, (p, n) {});
    expectedA = 0;
  }

  @override
  Future<void> run() async {
    final notifier = container.read(aProvider.notifier);
    for (int i = 0; i < BenchmarkConfig.complexGraphIterations; i++) {
      notifier.state++;
    }
    expectedA += BenchmarkConfig.complexGraphIterations;
    final value = container.read(dProvider);
    if (value != _expectedOutput(expectedA)) {
      throw StateError(
          'Riverpod graph mismatch: expected ${_expectedOutput(expectedA)}, got $value');
    }
  }

  @override
  Future<void> verify() async {
    final value = container.read(dProvider);
    if (container.read(aProvider) != expectedA ||
        value != _expectedOutput(expectedA)) {
      throw StateError(
          'Riverpod graph verification failed: a=${container.read(aProvider)}, d=$value, expectedA=$expectedA');
    }
  }

  @override
  Future<void> teardown() async {
    container.dispose();
  }
}

// --- BLoC ---
class BlocGraphBenchmark extends BenchmarkImplementation {
  late rxdart.BehaviorSubject<int> a;
  late rxdart.BehaviorSubject<int> dSubject;
  late StreamSubscription sub;
  int expectedA = 0;

  @override
  Future<void> setup() async {
    a = rxdart.BehaviorSubject.seeded(0, sync: true);
    final b = a.map((val) => val + 1);
    final c = a.map((val) => val * 2);

    // Use BehaviorSubject for D to enable synchronous .value reads
    dSubject = rxdart.BehaviorSubject.seeded(
      a.value + 1 + a.value * 2,
      sync: true,
    ); // Initial: b + c = 1 + 0 = 1

    final dStream = rxdart.Rx.combineLatest2(b, c, (valB, valC) => valB + valC);
    sub = dStream.listen((val) {
      dSubject.add(val);
    });
    expectedA = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.complexGraphIterations; i++) {
      a.add(a.value + 1);
    }
    expectedA += BenchmarkConfig.complexGraphIterations;
    await _waitForValue(
      current: () => dSubject.value,
      expected: _expectedOutput(expectedA),
      label: 'BLoC graph',
    );
  }

  @override
  Future<void> verify() async {
    if (a.value != expectedA || dSubject.value != _expectedOutput(expectedA)) {
      throw StateError(
          'BLoC graph verification failed: a=${a.value}, d=${dSubject.value}, expectedA=$expectedA');
    }
  }

  @override
  Future<void> teardown() async {
    await sub.cancel();
    await dSubject.close();
    await a.close();
  }
}

int _expectedOutput(int aValue) => aValue + 1 + (aValue * 2);

Future<void> _waitForValue({
  required int Function() current,
  required int expected,
  required String label,
}) async {
  for (int attempts = 0; attempts < 20000; attempts++) {
    if (current() == expected) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('$label did not settle to $expected (got ${current()})');
}
