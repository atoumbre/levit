import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:levit_flutter/levit_flutter.dart';
import '../../benchmark_engine.dart';

class LargeListBenchmark extends Benchmark {
  @override
  String get name => 'Large List Update (UI)';

  @override
  String get description =>
      'Renders 1,000 items. Updates one random item per run. Measures rebuild time.';

  @override
  bool get isUI => true;

  @override
  BenchmarkImplementation createImplementation(Framework framework) {
    switch (framework) {
      case Framework.levit:
        return LevitLargeList();
      case Framework.vanilla:
        return VanillaLargeList();
      case Framework.getx:
        return GetXLargeList();
      case Framework.bloc:
        return BlocLargeList();
      case Framework.riverpod:
        return RiverpodLargeList();
    }
  }
}

// --- Levit ---
class LevitLargeList extends BenchmarkImplementation {
  late LxList<String> items;
  final int count = 1000;
  final Random rng = Random();

  @override
  Future<void> setup() async {
    items = LxList(List.generate(count, (i) => 'Item $i'));
  }

  @override
  Future<int> run() async {
    final index = rng.nextInt(count);
    items[index] = 'Updated $index ${DateTime.now().millisecond}';
    return 0; // Cost handled by UI Runner
  }

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          return Text(items[index]);
        },
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
class VanillaLargeList extends BenchmarkImplementation {
  late ValueNotifier<List<String>> items;
  final int count = 1000;
  final Random rng = Random();

  @override
  Future<void> setup() async {
    items = ValueNotifier(List.generate(count, (i) => 'Item $i'));
  }

  @override
  Future<int> run() async {
    final index = rng.nextInt(count);
    items.value[index] = 'Updated $index ${DateTime.now().millisecond}';
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    items.notifyListeners();
    return 0;
  }

  @override
  Future<void> teardown() async {
    items.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: items,
      builder: (context, list, _) {
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => Text(list[index]),
        );
      },
    );
  }
}

// --- GetX ---
class GetXLargeList extends BenchmarkImplementation {
  late RxList<String> items;
  final int count = 1000;
  final Random rng = Random();

  @override
  Future<void> setup() async {
    items = List.generate(count, (i) => 'Item $i').obs;
  }

  @override
  Future<int> run() async {
    final index = rng.nextInt(count);
    items[index] = 'Updated $index ${DateTime.now().millisecond}';
    return 0;
  }

  @override
  Future<void> teardown() async {}

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) => Text(items[index]),
      );
    });
  }
}

// --- BLoC ---
class ListCubit extends Cubit<List<String>> {
  ListCubit(int count) : super(List.generate(count, (i) => 'Item $i'));

  void updateItem(int index, String val) {
    final newList = List<String>.from(state);
    newList[index] = val;
    emit(newList);
  }
}

class BlocLargeList extends BenchmarkImplementation {
  late ListCubit cubit;
  final int count = 1000;
  final Random rng = Random();

  @override
  Future<void> setup() async {
    cubit = ListCubit(count);
  }

  @override
  Future<int> run() async {
    final index = rng.nextInt(count);
    cubit.updateItem(index, 'Updated $index ${DateTime.now().millisecond}');
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
      child: BlocBuilder<ListCubit, List<String>>(
        builder: (context, list) {
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) => Text(list[index]),
          );
        },
      ),
    );
  }
}

// --- Riverpod ---
final listProvider = StateProvider<List<String>>((ref) => []);

class RiverpodLargeList extends BenchmarkImplementation {
  late ProviderContainer container;
  final int count = 1000;
  final Random rng = Random();

  @override
  Future<void> setup() async {
    container = ProviderContainer(overrides: [
      listProvider
          .overrideWith((ref) => List.generate(count, (i) => 'Item $i')),
    ]);
  }

  @override
  Future<int> run() async {
    final index = rng.nextInt(count);
    container.read(listProvider.notifier).update((state) {
      final newList = List<String>.from(state);
      newList[index] = 'Updated $index ${DateTime.now().millisecond}';
      return newList;
    });
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
      child: Consumer(
        builder: (context, ref, _) {
          final list = ref.watch(listProvider);
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) => Text(list[index]),
          );
        },
      ),
    );
  }
}
