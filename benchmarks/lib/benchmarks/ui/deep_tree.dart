import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:levit_flutter/levit_flutter.dart';
import '../../benchmark_engine.dart';

class DeepTreeBenchmark extends Benchmark {
  @override
  String get name => 'Deep Tree Propagation (UI)';

  @override
  String get description =>
      'Updates a value at the root of a 100-deep widget tree. Measures time to update the leaf.';

  @override
  bool get isUI => true;

  @override
  BenchmarkImplementation createImplementation(Framework framework) {
    switch (framework) {
      case Framework.levit:
        return LevitDeepTree();
      case Framework.vanilla:
        return VanillaDeepTree();
      case Framework.getx:
        return GetXDeepTree();
      case Framework.bloc:
        return BlocDeepTree();
      case Framework.riverpod:
        return RiverpodDeepTree();
    }
  }
}

// Helper to build deep tree
Widget buildDeepTree(int depth, Widget leaf) {
  if (depth <= 0) return leaf;
  return Container(
    padding: EdgeInsets.zero,
    child: buildDeepTree(depth - 1, leaf),
  );
}

// --- Levit ---
class LevitDeepTree extends BenchmarkImplementation {
  late LxVar<int> counter;

  @override
  Future<void> setup() async {
    counter = LxVar(0);
  }

  @override
  Future<int> run() async {
    counter.value++;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return buildDeepTree(100, LWatch(() {
      // Access value to subscribe
      return Text('Value: ${counter.value}');
    }));
  }

  @override
  Future<void> teardown() async {
    counter.close();
  }
}

// --- Vanilla ---
class VanillaDeepTree extends BenchmarkImplementation {
  late ValueNotifier<int> counter;

  @override
  Future<void> setup() async {
    counter = ValueNotifier(0);
  }

  @override
  Future<int> run() async {
    counter.value++;
    return 0;
  }

  @override
  Future<void> teardown() async {
    counter.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildDeepTree(
        100,
        ValueListenableBuilder<int>(
          valueListenable: counter,
          builder: (context, value, _) {
            return Text('Value: $value');
          },
        ));
  }
}

// --- GetX ---
class GetXDeepTree extends BenchmarkImplementation {
  late RxInt counter;

  @override
  Future<void> setup() async {
    counter = 0.obs;
  }

  @override
  Future<int> run() async {
    counter.value++;
    return 0;
  }

  @override
  Future<void> teardown() async {
    counter.close();
  }

  @override
  Widget build(BuildContext context) {
    return buildDeepTree(100, Obx(() {
      return Text('Value: ${counter.value}');
    }));
  }
}

// --- BLoC ---
class DeepCounterCubit extends Cubit<int> {
  DeepCounterCubit() : super(0);
  void increment() => emit(state + 1);
}

class BlocDeepTree extends BenchmarkImplementation {
  late DeepCounterCubit cubit;

  @override
  Future<void> setup() async {
    cubit = DeepCounterCubit();
  }

  @override
  Future<int> run() async {
    cubit.increment();
    return 0;
  }

  @override
  Future<void> teardown() async {
    await cubit.close();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit,
      child: buildDeepTree(100, BlocBuilder<DeepCounterCubit, int>(
        builder: (context, state) {
          return Text('Value: $state');
        },
      )),
    );
  }
}

// --- Riverpod ---
final deepProvider = StateProvider<int>((ref) => 0);

class RiverpodDeepTree extends BenchmarkImplementation {
  late ProviderContainer container;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
  }

  @override
  Future<int> run() async {
    container.read(deepProvider.notifier).state++;
    return 0;
  }

  @override
  Future<void> teardown() async {
    container.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: container,
      child: buildDeepTree(100, Consumer(
        builder: (context, ref, _) {
          final val = ref.watch(deepProvider);
          return Text('Value: $val');
        },
      )),
    );
  }
}
