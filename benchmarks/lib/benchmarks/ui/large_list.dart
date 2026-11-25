import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../benchmark_engine.dart';

class LargeListBenchmark extends Benchmark {
  @override
  String get name => 'Virtualized List: Visible Row Update (UI)';

  @override
  String get description =>
      'A 1,000-item virtualized list; changes the first visible row and rebuilds the list wrapper.';

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

abstract class _LargeListBase extends BenchmarkImplementation {
  final int count = 1000;
  final List<String> items = <String>[];
  int renderedVersion = 0;
  int updateVersion = 0;
  int lastUpdatedIndex = 0;

  @override
  Future<void> setup() async {
    items
      ..clear()
      ..addAll(List.generate(count, (i) => 'Item $i'));
    renderedVersion = 0;
    updateVersion = 0;
    lastUpdatedIndex = 0;
  }

  @override
  Future<void> run() async {
    lastUpdatedIndex = 0;
    updateVersion++;
    items[lastUpdatedIndex] = 'Updated $lastUpdatedIndex #$updateVersion';
    notifyUpdate();
  }

  @override
  Future<void> verify() async {
    final expectedValue = 'Updated $lastUpdatedIndex #$updateVersion';
    if (items[lastUpdatedIndex] != expectedValue) {
      throw StateError(
        'Large list mismatch at $lastUpdatedIndex: expected $expectedValue, got ${items[lastUpdatedIndex]}',
      );
    }
    if (currentVersion != updateVersion || renderedVersion != updateVersion) {
      throw StateError(
        'Large list version mismatch: expected $updateVersion, got $currentVersion',
      );
    }
  }

  @override
  Future<void> teardown() async {
    items.clear();
  }

  void notifyUpdate();

  int get currentVersion;

  Widget buildList() {
    renderedVersion = currentVersion;
    return ListView.builder(
      itemExtent: 24,
      itemCount: items.length,
      itemBuilder: (context, index) => Text(items[index]),
    );
  }
}

class LevitLargeList extends _LargeListBase {
  late LxVar<int> version;

  @override
  Future<void> setup() async {
    await super.setup();
    version = LxVar(0);
  }

  @override
  void notifyUpdate() {
    version.value = updateVersion;
  }

  @override
  int get currentVersion => version.value;

  @override
  Widget build(BuildContext context) {
    return LBuilder(version, (_) => buildList());
  }

  @override
  Future<void> teardown() async {
    await super.teardown();
    await version.close();
  }
}

class VanillaLargeList extends _LargeListBase {
  late ValueNotifier<int> version;

  @override
  Future<void> setup() async {
    await super.setup();
    version = ValueNotifier(0);
  }

  @override
  void notifyUpdate() {
    version.value = updateVersion;
  }

  @override
  int get currentVersion => version.value;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: version,
      builder: (context, _, __) => buildList(),
    );
  }

  @override
  Future<void> teardown() async {
    await super.teardown();
    version.dispose();
  }
}

class GetXLargeList extends _LargeListBase {
  late RxInt version;

  @override
  Future<void> setup() async {
    await super.setup();
    version = 0.obs;
  }

  @override
  void notifyUpdate() {
    version.value = updateVersion;
  }

  @override
  int get currentVersion => version.value;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      version.value;
      return buildList();
    });
  }

  @override
  Future<void> teardown() async {
    await super.teardown();
    version.close();
  }
}

class _ListVersionCubit extends Cubit<int> {
  _ListVersionCubit() : super(0);

  void publish(int version) => emit(version);
}

class BlocLargeList extends _LargeListBase {
  late _ListVersionCubit cubit;

  @override
  Future<void> setup() async {
    await super.setup();
    cubit = _ListVersionCubit();
  }

  @override
  void notifyUpdate() {
    cubit.publish(updateVersion);
  }

  @override
  int get currentVersion => cubit.state;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit,
      child: BlocBuilder<_ListVersionCubit, int>(
        builder: (context, _) => buildList(),
      ),
    );
  }

  @override
  Future<void> teardown() async {
    await super.teardown();
    await cubit.close();
  }
}

final listVersionProvider = StateProvider<int>((ref) => 0);

class RiverpodLargeList extends _LargeListBase {
  late ProviderContainer container;

  @override
  Future<void> setup() async {
    await super.setup();
    container = ProviderContainer();
  }

  @override
  void notifyUpdate() {
    container.read(listVersionProvider.notifier).state = updateVersion;
  }

  @override
  int get currentVersion => container.read(listVersionProvider);

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          ref.watch(listVersionProvider);
          return buildList();
        },
      ),
    );
  }

  @override
  Future<void> teardown() async {
    await super.teardown();
    container.dispose();
  }
}
