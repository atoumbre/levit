import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../benchmark_engine.dart';

/// Benchmark for animated state updates at 60fps.
/// Tests framework overhead during continuous animation.
class AnimatedStateBenchmark extends Benchmark {
  @override
  String get name => 'Animated State - 60fps (UI)';

  @override
  String get description =>
      'State update triggering widget rebuild. Tests per-frame overhead.';

  @override
  bool get isUI => true;

  @override
  BenchmarkImplementation createImplementation(Framework framework) {
    switch (framework) {
      case Framework.levit:
        return LevitAnimatedBenchmark();
      case Framework.vanilla:
        return VanillaAnimatedBenchmark();
      case Framework.getx:
        return GetXAnimatedBenchmark();
      case Framework.bloc:
        return BlocAnimatedBenchmark();
      case Framework.riverpod:
        return RiverpodAnimatedBenchmark();
    }
  }
}

// --- Levit ---
class LevitAnimatedBenchmark extends BenchmarkImplementation {
  late LxVar<double> progress;
  int frameCount = 0;

  @override
  Future<void> setup() async {
    progress = LxVar(0.0);
    frameCount = 0;
  }

  @override
  Future<void> run() async {
    frameCount++;
    progress.value = (frameCount % 120) / 120.0;
  }

  @override
  Future<void> verify() async {
    final expected = (frameCount % 120) / 120.0;
    if (progress.value != expected) {
      throw StateError(
          'Levit animation mismatch: expected $expected, got ${progress.value}');
    }
  }

  @override
  Future<void> teardown() async {
    progress.close();
  }

  @override
  Widget build(BuildContext context) {
    return LBuilder(progress, (progress) {
      return Container(
        width: 200,
        height: 20,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue),
        ),
        child: FractionallySizedBox(
          widthFactor: progress,
          alignment: Alignment.centerLeft,
          child: Container(color: Colors.blue),
        ),
      );
    });
  }
}

// --- Vanilla ---
class VanillaAnimatedBenchmark extends BenchmarkImplementation {
  late ValueNotifier<double> progress;
  int frameCount = 0;

  @override
  Future<void> setup() async {
    progress = ValueNotifier(0.0);
    frameCount = 0;
  }

  @override
  Future<void> run() async {
    frameCount++;
    progress.value = (frameCount % 120) / 120.0;
  }

  @override
  Future<void> verify() async {
    final expected = (frameCount % 120) / 120.0;
    if (progress.value != expected) {
      throw StateError(
          'Vanilla animation mismatch: expected $expected, got ${progress.value}');
    }
  }

  @override
  Future<void> teardown() async {
    progress.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, value, _) {
        return Container(
          width: 200,
          height: 20,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
          ),
          child: FractionallySizedBox(
            widthFactor: value,
            alignment: Alignment.centerLeft,
            child: Container(color: Colors.grey),
          ),
        );
      },
    );
  }
}

// --- GetX ---
class GetXAnimatedBenchmark extends BenchmarkImplementation {
  late RxDouble progress;
  int frameCount = 0;

  @override
  Future<void> setup() async {
    progress = 0.0.obs;
    frameCount = 0;
  }

  @override
  Future<void> run() async {
    frameCount++;
    progress.value = (frameCount % 120) / 120.0;
  }

  @override
  Future<void> verify() async {
    final expected = (frameCount % 120) / 120.0;
    if (progress.value != expected) {
      throw StateError(
          'GetX animation mismatch: expected $expected, got ${progress.value}');
    }
  }

  @override
  Future<void> teardown() async {
    progress.close();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Container(
        width: 200,
        height: 20,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.purple),
        ),
        child: FractionallySizedBox(
          widthFactor: progress.value,
          alignment: Alignment.centerLeft,
          child: Container(color: Colors.purple),
        ),
      );
    });
  }
}

// --- Riverpod ---
final _animProgressProvider = StateProvider<double>((ref) => 0.0);

class RiverpodAnimatedBenchmark extends BenchmarkImplementation {
  late ProviderContainer container;
  int frameCount = 0;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    frameCount = 0;
  }

  @override
  Future<void> run() async {
    frameCount++;
    container.read(_animProgressProvider.notifier).state =
        (frameCount % 120) / 120.0;
  }

  @override
  Future<void> verify() async {
    final expected = (frameCount % 120) / 120.0;
    final value = container.read(_animProgressProvider);
    if (value != expected) {
      throw StateError(
          'Riverpod animation mismatch: expected $expected, got $value');
    }
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
          final value = ref.watch(_animProgressProvider);
          return Container(
            width: 200,
            height: 20,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.teal),
            ),
            child: FractionallySizedBox(
              widthFactor: value,
              alignment: Alignment.centerLeft,
              child: Container(color: Colors.teal),
            ),
          );
        },
      ),
    );
  }
}

// --- BLoC (proper Cubit implementation) ---
class AnimationProgressCubit extends Cubit<double> {
  AnimationProgressCubit() : super(0.0);

  void updateProgress(double value) => emit(value);
}

class BlocAnimatedBenchmark extends BenchmarkImplementation {
  late AnimationProgressCubit cubit;
  int frameCount = 0;

  @override
  Future<void> setup() async {
    cubit = AnimationProgressCubit();
    frameCount = 0;
  }

  @override
  Future<void> run() async {
    frameCount++;
    cubit.updateProgress((frameCount % 120) / 120.0);
  }

  @override
  Future<void> verify() async {
    final expected = (frameCount % 120) / 120.0;
    if (cubit.state != expected) {
      throw StateError(
          'BLoC animation mismatch: expected $expected, got ${cubit.state}');
    }
  }

  @override
  Future<void> teardown() async {
    await cubit.close();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit,
      child: BlocBuilder<AnimationProgressCubit, double>(
        builder: (context, value) {
          return Container(
            width: 200,
            height: 20,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red),
            ),
            child: FractionallySizedBox(
              widthFactor: value,
              alignment: Alignment.centerLeft,
              child: Container(color: Colors.red),
            ),
          );
        },
      ),
    );
  }
}
