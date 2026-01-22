import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levit_reactive/levit_reactive.dart';
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

  @override
  Future<void> setup() async {
    a = LxVar(0);
    // Use synchronous LxComputed for fair comparison
    b = LxComputed(() => a.value + 1);
    c = LxComputed(() => a.value * 2);
    // Access .computedValue to get the actual int value
    d = LxComputed(() => b.value + c.value);

    listener = () {};
    d.addListener(listener);
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 100000; i++) {
      a.value++;
      final _ = d.value;
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
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
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 100000; i++) {
      a.value++;
      final _ = d.value; // Read to ensure computation like Levit
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
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
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 100000; i++) {
      a.value++;
      final _ = dVal.value; // Read to ensure computation like Levit
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
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

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    bProvider = Provider((ref) => ref.watch(aProvider) + 1);
    cProvider = Provider((ref) => ref.watch(aProvider) * 2);
    dProvider = Provider((ref) => ref.watch(bProvider) + ref.watch(cProvider));

    container.listen(dProvider, (p, n) {});
  }

  @override
  Future<int> run() async {
    final notifier = container.read(aProvider.notifier);
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 100000; i++) {
      notifier.state++;
      container.read(dProvider);
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
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

  @override
  Future<void> setup() async {
    a = rxdart.BehaviorSubject.seeded(0);
    final b = a.map((val) => val + 1);
    final c = a.map((val) => val * 2);

    // Use BehaviorSubject for D to enable synchronous .value reads
    dSubject = rxdart.BehaviorSubject.seeded(
        a.value + 1 + a.value * 2); // Initial: b + c = 1 + 0 = 1

    final dStream = rxdart.Rx.combineLatest2(b, c, (valB, valC) => valB + valC);
    sub = dStream.listen((val) {
      dSubject.add(val);
    });
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 100000; i++) {
      a.add(i);
      final _ = dSubject.value; // Read to ensure computation like Levit
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    await sub.cancel();
    await dSubject.close();
    await a.close();
  }
}
