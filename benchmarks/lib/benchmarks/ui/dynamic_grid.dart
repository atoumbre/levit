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
      'Replaces 50 of 200 keyed items; verifies visible cells mount and unmount during each replacement.';

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

class _GridItem extends StatefulWidget {
  final int value;
  final Set<int> mountedItems;
  final VoidCallback onMount;
  final VoidCallback onUnmount;

  _GridItem(this.value, this.mountedItems, this.onMount, this.onUnmount)
    : super(key: ValueKey(value));

  @override
  State<_GridItem> createState() => _GridItemState();
}

class _GridItemState extends State<_GridItem> {
  @override
  void initState() {
    super.initState();
    widget.mountedItems.add(widget.value);
    widget.onMount();
  }

  @override
  void dispose() {
    widget.mountedItems.remove(widget.value);
    widget.onUnmount();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.primaries[widget.value % Colors.primaries.length],
    child: Center(
      child: Text('${widget.value}', style: const TextStyle(fontSize: 10)),
    ),
  );
}

abstract class _DynamicGridBase extends BenchmarkImplementation {
  final List<int> items = <int>[];
  int nextItem = 0;
  int updateVersion = 0;
  int renderedVersion = 0;
  final mountedItems = <int>{};
  int mounts = 0;
  int unmounts = 0;
  int mountsBefore = 0;
  int unmountsBefore = 0;

  @override
  Future<void> setup() async {
    items
      ..clear()
      ..addAll(List.generate(200, (i) => i));
    mountedItems.clear();
    mounts = unmounts = mountsBefore = unmountsBefore = 0;
    renderedVersion = 0;
    nextItem = 200;
    updateVersion = 0;
  }

  @override
  Future<void> run() async {
    mountsBefore = mounts;
    unmountsBefore = unmounts;
    for (int i = 0; i < 50; i++) {
      items.add(nextItem++);
    }
    if (items.length > 200) {
      items.removeRange(0, 50);
    }
    updateVersion++;
    notifyUpdate();
  }

  @override
  Future<void> verify() async {
    if (mounts <= mountsBefore ||
        unmounts <= unmountsBefore ||
        mountedItems.any((id) => !items.contains(id))) {
      throw StateError(
        'Grid replacement must mount new visible cells and unmount removed cells',
      );
    }
    final expectedLength = nextItem <= 200 ? nextItem : 200;
    if (items.length != expectedLength) {
      throw StateError(
        'Dynamic grid length mismatch: expected $expectedLength, got ${items.length}',
      );
    }
    if (currentVersion != updateVersion || renderedVersion != updateVersion) {
      throw StateError(
        'Dynamic grid version mismatch: expected $updateVersion, got $currentVersion',
      );
    }
  }

  @override
  Future<void> teardown() async {
    if (mountedItems.isNotEmpty) {
      throw StateError('Grid must be unmounted before teardown');
    }
    items.clear();
  }

  void notifyUpdate();

  int get currentVersion;

  Widget buildGrid() {
    renderedVersion = currentVersion;
    final indices = {for (var i = 0; i < items.length; i++) items[i]: i};
    return GridView.builder(
      findChildIndexCallback: (key) => indices[(key as ValueKey<int>).value],
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) =>
          _GridItem(items[i], mountedItems, () => mounts++, () => unmounts++),
    );
  }
}

class LevitDynamicGrid extends _DynamicGridBase {
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
    return LBuilder(version, (_) => buildGrid());
  }

  @override
  Future<void> teardown() async {
    await super.teardown();
    await version.close();
  }
}

class VanillaDynamicGrid extends _DynamicGridBase {
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
      builder: (ctx, _, __) => buildGrid(),
    );
  }

  @override
  Future<void> teardown() async {
    await super.teardown();
    version.dispose();
  }
}

class GetXDynamicGrid extends _DynamicGridBase {
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
      return buildGrid();
    });
  }

  @override
  Future<void> teardown() async {
    await super.teardown();
    version.close();
  }
}

class _GridVersionCubit extends Cubit<int> {
  _GridVersionCubit() : super(0);

  void publish(int version) => emit(version);
}

class BlocDynamicGrid extends _DynamicGridBase {
  late _GridVersionCubit cubit;

  @override
  Future<void> setup() async {
    await super.setup();
    cubit = _GridVersionCubit();
  }

  @override
  void notifyUpdate() {
    cubit.publish(updateVersion);
  }

  @override
  int get currentVersion => cubit.state;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_GridVersionCubit, int>(
      bloc: cubit,
      builder: (ctx, _) => buildGrid(),
    );
  }

  @override
  Future<void> teardown() async {
    await super.teardown();
    await cubit.close();
  }
}

final gridVersionProvider = StateProvider<int>((ref) => 0);

class RiverpodDynamicGrid extends _DynamicGridBase {
  late ProviderContainer container;

  @override
  Future<void> setup() async {
    await super.setup();
    container = ProviderContainer();
  }

  @override
  void notifyUpdate() {
    container.read(gridVersionProvider.notifier).state = updateVersion;
  }

  @override
  int get currentVersion => container.read(gridVersionProvider);

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (ctx, ref, _) {
          ref.watch(gridVersionProvider);
          return buildGrid();
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
