import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../benchmark_engine.dart';

class DynamicGridBenchmark extends Benchmark {
  @override
  String get name => 'Dynamic Grid Churn (UI)';

  @override
  String get description =>
      'Adds and removes 50 widgets per frame. Tests allocation and mount/unmount overhead.';

  @override
  bool get isUI => true;

  @override
  BenchmarkImplementation createImplementation(Framework framework) {
    switch (framework) {
      case Framework.levit:
        return LevitDynamicGrid();
      case Framework.vanilla:
        return VanillaDynamicGrid();
      case Framework.getx:
        return GetXDynamicGrid();
      case Framework.bloc:
        return BlocDynamicGrid();
      case Framework.riverpod:
        return RiverpodDynamicGrid();
    }
  }
}

// --- Common UI ---
class _GridItem extends StatelessWidget {
  final int value;
  const _GridItem(this.value);

  @override
  Widget build(BuildContext context) {
    // Simple widget to test mount cost
    return Container(
      color: Colors.primaries[value % Colors.primaries.length],
      child:
          Center(child: Text('$value', style: const TextStyle(fontSize: 10))),
    );
  }
}

// --- Levit ---
class LevitDynamicGrid extends BenchmarkImplementation {
  final LxList<int> items = <int>[].lx;
  int _counter = 0;

  @override
  Future<void> setup() async {
    _counter = 0;
    items.clear();
  }

  @override
  Future<int> run() async {
    // Churn: Add 50, Remove 20 oldest
    for (int i = 0; i < 50; i++) {
      items.add(_counter++);
    }
    if (items.length > 200) {
      items.removeRange(0, 50);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      return GridView.builder(
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _GridItem(items[i]),
      );
    });
  }

  @override
  Future<void> teardown() async {
    items.clear();
    items.close();
  }
}

// --- Vanilla ---
class VanillaDynamicGrid extends BenchmarkImplementation {
  final ValueNotifier<List<int>> items = ValueNotifier([]);
  int _counter = 0;

  @override
  Future<void> setup() async {
    _counter = 0;
    items.value = [];
  }

  @override
  Future<int> run() async {
    final list = List<int>.from(items.value);
    for (int i = 0; i < 50; i++) {
      list.add(_counter++);
    }
    if (list.length > 200) {
      list.removeRange(0, 50);
    }
    items.value = list;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<int>>(
      valueListenable: items,
      builder: (ctx, list, _) {
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10),
          itemCount: list.length,
          itemBuilder: (ctx, i) => _GridItem(list[i]),
        );
      },
    );
  }

  @override
  Future<void> teardown() async {
    items.dispose();
  }
}

// --- GetX ---
class GetXDynamicGrid extends BenchmarkImplementation {
  final RxList<int> items = <int>[].obs;
  int _counter = 0;

  @override
  Future<void> setup() async {
    _counter = 0;
    items.clear();
  }

  @override
  Future<int> run() async {
    for (int i = 0; i < 50; i++) {
      items.add(_counter++);
    }
    if (items.length > 200) {
      items.removeRange(0, 50);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return GridView.builder(
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _GridItem(items[i]),
      );
    });
  }

  @override
  Future<void> teardown() async {
    items.close();
  }
}

// --- BLoC ---
class _GridCubit extends Cubit<List<int>> {
  _GridCubit() : super([]);
  int _counter = 0;

  void churn() {
    final list = List<int>.from(state);
    for (int i = 0; i < 50; i++) {
      list.add(_counter++);
    }
    if (list.length > 200) {
      list.removeRange(0, 50);
    }
    emit(list);
  }
}

class BlocDynamicGrid extends BenchmarkImplementation {
  // ignore: library_private_types_in_public_api
  late _GridCubit cubit;

  @override
  Future<void> setup() async {
    cubit = _GridCubit();
  }

  @override
  Future<int> run() async {
    cubit.churn();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_GridCubit, List<int>>(
      bloc: cubit,
      builder: (ctx, list) {
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10),
          itemCount: list.length,
          itemBuilder: (ctx, i) => _GridItem(list[i]),
        );
      },
    );
  }

  @override
  Future<void> teardown() async {
    await cubit.close();
  }
}

// --- Riverpod ---
final gridProvider = StateProvider<List<int>>((ref) => []);
int _riverpodCounter = 0;

class RiverpodDynamicGrid extends BenchmarkImplementation {
  late ProviderContainer container;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    _riverpodCounter = 0;
    // Reset state
    container.read(gridProvider.notifier).state = [];
  }

  @override
  Future<int> run() async {
    final notifier = container.read(gridProvider.notifier);
    final list = List<int>.from(notifier.state);
    for (int i = 0; i < 50; i++) {
      list.add(_riverpodCounter++);
    }
    if (list.length > 200) {
      list.removeRange(0, 50);
    }
    notifier.state = list;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (ctx, ref, _) {
          final list = ref.watch(gridProvider);
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 10),
            itemCount: list.length,
            itemBuilder: (ctx, i) => _GridItem(list[i]),
          );
        },
      ),
    );
  }

  @override
  Future<void> teardown() async {
    container.dispose();
  }
}
