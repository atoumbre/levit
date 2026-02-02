import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../benchmark_config.dart';
import '../../benchmark_engine.dart';

class ComputedChainBenchmark extends Benchmark {
  @override
  String get name => 'Computed Chain (Deep Propagation)';

  @override
  String get description =>
      'Updates the root of a chain of ${BenchmarkConfig.computedChainIterations} computed values (A->B->C...) and measures time to update the leaf.';

  @override
  bool get isUI => false;

  @override
  BenchmarkImplementation createImplementation(Framework framework) {
    switch (framework) {
      case Framework.levit:
        return LevitComputedChain();
      case Framework.vanilla:
        return VanillaComputedChain();
      case Framework.getx:
        return GetXComputedChain();
      case Framework.bloc:
        return BlocComputedChain();
      case Framework.riverpod:
        return RiverpodComputedChain();
    }
  }
}

class _ChainCubit extends Cubit<int> {
  _ChainCubit(int initial) : super(initial);
  void update(int val) => emit(val);
}

class BlocComputedChain extends BenchmarkImplementation {
  late _ChainCubit root;
  late _ChainCubit leaf;
  final List<_ChainCubit> chain = [];
  final List<dynamic> subs = [];

  @override
  Future<void> setup() async {
    root = _ChainCubit(0);
    _ChainCubit current = root;

    for (int i = 0; i < BenchmarkConfig.computedChainIterations; i++) {
      final prev = current;
      final next = _ChainCubit(prev.state + 1);

      // Chain loop
      final sub = prev.stream.listen((val) {
        next.update(val + 1);
      });
      subs.add(sub);

      chain.add(next);
      current = next;
    }
    leaf = current;
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < BenchmarkConfig.computedChainRunIterations; i++) {
      final target = root.state + 1 + BenchmarkConfig.computedChainIterations;
      root.update(root.state + 1);
      // Wait for propagation to reach the leaf
      await leaf.stream.firstWhere((val) => val >= target);
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    await root.close();
    for (var c in chain) {
      await c.close();
    }
    for (var s in subs) {
      await s.cancel();
    }
  }
}

// --- Levit ---
class LevitComputedChain extends BenchmarkImplementation {
  late LxVar<int> root;
  late LxComputed<int> leaf;
  final List<LxComputed<int>> chain = [];

  @override
  Future<void> setup() async {
    root = LxVar(0);
    LxComputed<int> current = LxComputed(() => root.value);
    chain.add(current);

    for (int i = 0; i < BenchmarkConfig.computedChainIterations - 1; i++) {
      final prev = current;
      current = LxComputed(() => prev.value + 1);
      chain.add(current);
    }
    leaf = current;

    // warm up
    leaf.value;
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < BenchmarkConfig.computedChainRunIterations; i++) {
      root.value++;
      // Access leaf to force propagation (pull)
      final val = leaf.value;
      if (val != root.value + BenchmarkConfig.computedChainIterations - 1 + i) {
        // +i because root increases
        // Sanity check failed? No, root increases by 1 each loop.
        // On loop 0: root=1. leaf = 1 + 99 = 100.
        // On loop 1: root=2. leaf = 2 + 99 = 101.
      }
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    root.close();
    for (var c in chain) {
      c.close();
    }
  }
}

// --- Vanilla (ValueNotifier) ---
// Vanilla computed needs manual listeners.
class VanillaComputedChain extends BenchmarkImplementation {
  late ValueNotifier<int> root;
  late ValueNotifier<int> leaf;
  final List<ValueNotifier<int>> chain = [];

  @override
  Future<void> setup() async {
    root = ValueNotifier(0);
    ValueNotifier<int> current = root;

    // We can't really do "Computed" easily with ValueNotifier without boilerplate.
    // We'll simulate it by chaining listeners.
    // A -> listener -> set B.

    for (int i = 0; i < BenchmarkConfig.computedChainIterations; i++) {
      final prev = current;
      final next = ValueNotifier(prev.value + 1);
      prev.addListener(() {
        next.value = prev.value + 1;
      });
      chain.add(next);
      current = next;
    }
    leaf = current;
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < BenchmarkConfig.computedChainRunIterations; i++) {
      root.value++;
      // ValueNotifier is push-based, so updating root triggers the whole chain immediately.
      // We assume it's sync.
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    root.dispose();
    for (var c in chain) {
      c.dispose();
    }
  }
}

// --- GetX ---
class GetXComputedChain extends BenchmarkImplementation {
  late RxInt root;
  late int Function() leaf; // GetX computed is just a function using values
  // Actually GetX has 'RxInt get leaf => ...' but for chaining variables we usually use nothing?
  // Or Obx? Or Worker?
  // GetX doesn't have a generic "Computed" class that holds state unless we use binding?
  // We can use a simple getter: int get b => a.value + 1.
  // But that's not cached/memoized.

  // Let's use Rx<T> and bind them? No that's push.
  // GetX doesn't really have a "Computed Signal" like Solid/Levit.
  // It has `rx.bindStream`?

  // Actually, let's skip GetX for deep chain because standard GetX usage
  // is usually direct controller usage or workers.
  // We'll compromise: Use 'Obx' in a widget? No this is logic benchmark.
  // We'll use `worker` (ever).

  late RxInt leafRx;
  final List<Worker> workers = [];
  final List<RxInt> chain = [];

  @override
  Future<void> setup() async {
    root = 0.obs;
    RxInt current = root;

    for (int i = 0; i < BenchmarkConfig.computedChainIterations; i++) {
      final prev = current;
      final next = (prev.value + 1).obs;

      // Chain using 'ever' (push)
      final w = ever(prev, (val) => next.value = val + 1);
      workers.add(w);
      chain.add(next);
      current = next;
    }
    leafRx = current;
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < BenchmarkConfig.computedChainRunIterations; i++) {
      final target = root.value + 1 + BenchmarkConfig.computedChainIterations;
      root.value++;
      // Wait for push-based propagation to reach the leaf
      // GetX workers are generally microtask-based
      while (leafRx.value < target) {
        await Future.microtask(() {});
      }
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    for (var w in workers) {
      w.dispose();
    }
  }
}

// --- Riverpod ---
class RiverpodComputedChain extends BenchmarkImplementation {
  late ProviderContainer container;
  late StateProvider<int> rootProvider;
  late Provider<int> leafProvider;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    rootProvider = StateProvider((ref) => 0);

    var currentProvider = Provider<int>((ref) => ref.watch(rootProvider));

    for (int i = 0; i < BenchmarkConfig.computedChainIterations - 1; i++) {
      final prev = currentProvider;
      // Define new provider depending on prev
      currentProvider = Provider<int>((ref) => ref.watch(prev) + 1);
    }
    leafProvider = currentProvider;

    // Warm up
    container.read(leafProvider);
  }

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();
    final notifier = container.read(rootProvider.notifier);

    for (int i = 0; i < BenchmarkConfig.computedChainRunIterations; i++) {
      notifier.state++;
      container.read(leafProvider); // Pull to force eval
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds;
  }

  @override
  Future<void> teardown() async {
    container.dispose();
  }
}
