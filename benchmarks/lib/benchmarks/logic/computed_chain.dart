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
  BenchmarkClassification get classification =>
      BenchmarkClassification.approximate;

  @override
  String get comparisonNote =>
      'An observed leaf consumes every root update through the closest computed/stream primitive.';

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
  int expectedRoot = 0;

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
    expectedRoot = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.computedChainRunIterations; i++) {
      final target = root.state + 1 + BenchmarkConfig.computedChainIterations;
      root.update(root.state + 1);
      // Wait for propagation to reach the leaf
      await leaf.stream.firstWhere((val) => val >= target);
    }
    expectedRoot += BenchmarkConfig.computedChainRunIterations;
  }

  @override
  Future<void> verify() async {
    final expectedLeaf = expectedRoot + BenchmarkConfig.computedChainIterations;
    if (root.state != expectedRoot || leaf.state != expectedLeaf) {
      throw StateError(
        'BLoC chain mismatch: root=${root.state}, leaf=${leaf.state}, expectedRoot=$expectedRoot, expectedLeaf=$expectedLeaf',
      );
    }
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
  LevitComputedChain({this.staticDeps = false});

  final bool staticDeps;
  late LxVar<int> root;
  late LxComputed<int> leaf;
  int observedLeaf = 0;
  int deliveries = 0;
  final List<LxComputed<int>> chain = [];
  int expectedRoot = 0;

  @override
  Future<void> setup() async {
    root = LxVar(0);
    LxComputed<int> current = LxComputed(
      () => root.value + 1,
      staticDeps: staticDeps,
    );
    chain
      ..clear()
      ..add(current);

    for (int i = 0; i < BenchmarkConfig.computedChainIterations - 1; i++) {
      final prev = current;
      current = LxComputed(() => prev.value + 1, staticDeps: staticDeps);
      chain.add(current);
    }
    leaf = current;

    leaf.addListener(() {
      observedLeaf = leaf.value;
      deliveries++;
    });
    observedLeaf = leaf.value;
    expectedRoot = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.computedChainRunIterations; i++) {
      root.value++;
      if (observedLeaf !=
          root.value + BenchmarkConfig.computedChainIterations) {
        throw StateError('Chain leaf has not consumed this root update');
      }
    }
    expectedRoot += BenchmarkConfig.computedChainRunIterations;
  }

  @override
  Future<void> verify() async {
    final expectedLeaf = expectedRoot + BenchmarkConfig.computedChainIterations;
    if (root.value != expectedRoot ||
        observedLeaf != expectedLeaf ||
        deliveries != expectedRoot) {
      throw StateError(
        'Levit chain mismatch: root=${root.value}, leaf=${leaf.value}, expectedRoot=$expectedRoot, expectedLeaf=$expectedLeaf',
      );
    }
  }

  @override
  Future<void> teardown() async {
    await root.close();
    for (var c in chain) {
      await c.close();
    }
  }
}

// --- Vanilla (ValueNotifier) ---
// Vanilla computed needs manual listeners.
class VanillaComputedChain extends BenchmarkImplementation {
  late ValueNotifier<int> root;
  late ValueNotifier<int> leaf;
  final List<ValueNotifier<int>> chain = [];
  int expectedRoot = 0;

  @override
  Future<void> setup() async {
    root = ValueNotifier(0);
    ValueNotifier<int> current = root;
    chain.clear();

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
    expectedRoot = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.computedChainRunIterations; i++) {
      root.value++;
    }
    expectedRoot += BenchmarkConfig.computedChainRunIterations;
  }

  @override
  Future<void> verify() async {
    final expectedLeaf = expectedRoot + BenchmarkConfig.computedChainIterations;
    if (root.value != expectedRoot || leaf.value != expectedLeaf) {
      throw StateError(
        'Vanilla chain mismatch: root=${root.value}, leaf=${leaf.value}, expectedRoot=$expectedRoot, expectedLeaf=$expectedLeaf',
      );
    }
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
  late RxInt leafRx;
  final List<Worker> workers = [];
  final List<RxInt> chain = [];
  int expectedRoot = 0;

  @override
  Future<void> setup() async {
    root = 0.obs;
    RxInt current = root;
    chain.clear();
    workers.clear();

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
    expectedRoot = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.computedChainRunIterations; i++) {
      final target = root.value + 1 + BenchmarkConfig.computedChainIterations;
      root.value++;
      while (leafRx.value < target) {
        await Future.microtask(() {});
      }
    }
    expectedRoot += BenchmarkConfig.computedChainRunIterations;
  }

  @override
  Future<void> verify() async {
    final expectedLeaf = expectedRoot + BenchmarkConfig.computedChainIterations;
    if (root.value != expectedRoot || leafRx.value != expectedLeaf) {
      throw StateError(
        'GetX chain mismatch: root=${root.value}, leaf=${leafRx.value}, expectedRoot=$expectedRoot, expectedLeaf=$expectedLeaf',
      );
    }
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
  int expectedRoot = 0;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    rootProvider = StateProvider((ref) => 0);

    var currentProvider = Provider<int>((ref) => ref.watch(rootProvider) + 1);

    for (int i = 0; i < BenchmarkConfig.computedChainIterations - 1; i++) {
      final prev = currentProvider;
      currentProvider = Provider<int>((ref) => ref.watch(prev) + 1);
    }
    leafProvider = currentProvider;

    container.listen(leafProvider, (_, __) {});
    container.read(leafProvider);
    expectedRoot = 0;
  }

  @override
  Future<void> run() async {
    final notifier = container.read(rootProvider.notifier);

    for (int i = 0; i < BenchmarkConfig.computedChainRunIterations; i++) {
      notifier.state++;
      container.read(leafProvider);
    }
    expectedRoot += BenchmarkConfig.computedChainRunIterations;
  }

  @override
  Future<void> verify() async {
    final expectedLeaf = expectedRoot + BenchmarkConfig.computedChainIterations;
    final rootValue = container.read(rootProvider);
    final leafValue = container.read(leafProvider);
    if (rootValue != expectedRoot || leafValue != expectedLeaf) {
      throw StateError(
        'Riverpod chain mismatch: root=$rootValue, leaf=$leafValue, expectedRoot=$expectedRoot, expectedLeaf=$expectedLeaf',
      );
    }
  }

  @override
  Future<void> teardown() async {
    container.dispose();
  }
}
