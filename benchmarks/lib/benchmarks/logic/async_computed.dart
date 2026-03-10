import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:rxdart/rxdart.dart' as rxdart;

import '../../benchmark_config.dart';
import '../../benchmark_engine.dart';

/// Benchmark for async computed values.
/// Tests frameworks' ability to handle async dependency tracking.
class AsyncComputedBenchmark extends Benchmark {
  @override
  String get name => 'Async Computed';

  @override
  String get description =>
      'Async computed that re-fetches on ${BenchmarkConfig.asyncComputedIterations} source changes. Tests async tracking.';

  @override
  bool get isUI => false;

  @override
  BenchmarkClassification get classification =>
      BenchmarkClassification.approximate;

  @override
  String get comparisonNote =>
      'Measures sequential async recomputation using each framework\'s closest async primitive.';

  @override
  BenchmarkImplementation createImplementation(Framework framework) {
    switch (framework) {
      case Framework.levit:
        return LevitAsyncComputedBenchmark();
      case Framework.vanilla:
        return VanillaAsyncComputedBenchmark();
      case Framework.getx:
        return GetXAsyncComputedBenchmark();
      case Framework.bloc:
        return BlocAsyncComputedBenchmark();
      case Framework.riverpod:
        return RiverpodAsyncComputedBenchmark();
    }
  }
}

// --- Levit ---
class LevitAsyncComputedBenchmark extends BenchmarkImplementation {
  late LxVar<int> source;
  late LxAsyncComputed<String> asyncComputed;
  late VoidCallback listener;
  int expectedSource = 0;

  @override
  Future<void> setup() async {
    source = LxVar(0);
    asyncComputed = LxComputed.async(() async {
      final val = source.value;
      await Future<void>.delayed(Duration.zero);
      return 'Result: $val';
    }, staticDeps: true);

    listener = () {};
    asyncComputed.addListener(listener);
    expectedSource = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.asyncComputedIterations; i++) {
      source.value++;
      expectedSource++;
      await _waitForLevitResult(asyncComputed, 'Result: $expectedSource');
    }
  }

  @override
  Future<void> verify() async {
    final value = asyncComputed.valueOrNull;
    if (value != 'Result: $expectedSource') {
      throw StateError(
          'Levit async mismatch: expected Result: $expectedSource, got $value');
    }
  }

  @override
  Future<void> teardown() async {
    asyncComputed.removeListener(listener);
    asyncComputed.close();
    source.close();
  }
}

// --- Vanilla (ValueNotifier with async listener) ---
class VanillaAsyncComputedBenchmark extends BenchmarkImplementation {
  late ValueNotifier<int> source;
  late ValueNotifier<String> result;
  bool _isProcessing = false;
  int expectedSource = 0;

  @override
  Future<void> setup() async {
    source = ValueNotifier(0);
    result = ValueNotifier('Result: 0');

    // Async listener that updates result
    source.addListener(() async {
      if (_isProcessing) return;
      _isProcessing = true;
      final val = source.value;
      await Future<void>.delayed(Duration.zero);
      result.value = 'Result: $val';
      _isProcessing = false;
    });
    expectedSource = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.asyncComputedIterations; i++) {
      source.value++;
      expectedSource++;
      await _waitForNotifierValue(result, 'Result: $expectedSource');
    }
  }

  @override
  Future<void> verify() async {
    if (result.value != 'Result: $expectedSource') {
      throw StateError(
          'Vanilla async mismatch: expected Result: $expectedSource, got ${result.value}');
    }
  }

  @override
  Future<void> teardown() async {
    source.dispose();
    result.dispose();
  }
}

// --- GetX (RxInt with async transformation) ---
class GetXAsyncComputedBenchmark extends BenchmarkImplementation {
  late RxInt source;
  late Rx<String> result;
  late StreamSubscription sub;
  int expectedSource = 0;

  @override
  Future<void> setup() async {
    source = 0.obs;
    result = 'Result: 0'.obs;

    sub = source.listen((val) async {
      await Future<void>.delayed(Duration.zero);
      result.value = 'Result: $val';
    });
    expectedSource = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.asyncComputedIterations; i++) {
      source.value++;
      expectedSource++;
      await _waitForRxValue(result, 'Result: $expectedSource');
    }
  }

  @override
  Future<void> verify() async {
    if (result.value != 'Result: $expectedSource') {
      throw StateError(
          'GetX async mismatch: expected Result: $expectedSource, got ${result.value}');
    }
  }

  @override
  Future<void> teardown() async {
    await sub.cancel();
    source.close();
    result.close();
  }
}

// --- Riverpod ---
class RiverpodAsyncComputedBenchmark extends BenchmarkImplementation {
  late ProviderContainer container;
  final sourceProvider = StateProvider<int>((ref) => 0);
  late FutureProvider<String> asyncProvider;
  int expectedSource = 0;

  @override
  Future<void> setup() async {
    container = ProviderContainer();
    asyncProvider = FutureProvider<String>((ref) async {
      final val = ref.watch(sourceProvider);
      await Future<void>.delayed(Duration.zero);
      return 'Result: $val';
    });
    container.listen(asyncProvider, (_, __) {});
    expectedSource = 0;
  }

  @override
  Future<void> run() async {
    final notifier = container.read(sourceProvider.notifier);
    for (int i = 0; i < BenchmarkConfig.asyncComputedIterations; i++) {
      notifier.state++;
      expectedSource++;
      final value = await container.read(asyncProvider.future);
      if (value != 'Result: $expectedSource') {
        throw StateError(
            'Riverpod async mismatch: expected Result: $expectedSource, got $value');
      }
    }
  }

  @override
  Future<void> verify() async {
    final value = await container.read(asyncProvider.future);
    if (value != 'Result: $expectedSource') {
      throw StateError(
          'Riverpod async verification failed: expected Result: $expectedSource, got $value');
    }
  }

  @override
  Future<void> teardown() async {
    container.dispose();
  }
}

// --- BLoC (RxDart with async transformation) ---
class BlocAsyncComputedBenchmark extends BenchmarkImplementation {
  late rxdart.BehaviorSubject<int> source;
  late StreamSubscription sub;
  String latestResult = 'Result: 0';
  int expectedSource = 0;

  @override
  Future<void> setup() async {
    source = rxdart.BehaviorSubject.seeded(0);
    sub = source.listen((val) async {
      await Future<void>.delayed(Duration.zero);
      latestResult = 'Result: $val';
    });
    latestResult = 'Result: 0';
    expectedSource = 0;
  }

  @override
  Future<void> run() async {
    for (int i = 0; i < BenchmarkConfig.asyncComputedIterations; i++) {
      source.add(source.value + 1);
      expectedSource++;
      await _waitForStringValue(
        current: () => latestResult,
        expected: 'Result: $expectedSource',
        label: 'BLoC async',
      );
    }
  }

  @override
  Future<void> verify() async {
    if (latestResult != 'Result: $expectedSource') {
      throw StateError(
          'BLoC async mismatch: expected Result: $expectedSource, got $latestResult');
    }
  }

  @override
  Future<void> teardown() async {
    await sub.cancel();
    await source.close();
  }
}

Future<void> _waitForLevitResult(
  LxAsyncComputed<String> computed,
  String expected,
) async {
  if (computed.valueOrNull == expected) return;
  final status = await computed.stream.firstWhere(
    (status) => status.valueOrNull == expected || status is LxError<String>,
  );
  if (status is LxError<String>) {
    throw status.error;
  }
}

Future<void> _waitForNotifierValue(
  ValueNotifier<String> notifier,
  String expected,
) async {
  if (notifier.value == expected) return;
  final completer = Completer<void>();

  void listener() {
    if (notifier.value == expected && !completer.isCompleted) {
      notifier.removeListener(listener);
      completer.complete();
    }
  }

  notifier.addListener(listener);
  await completer.future;
}

Future<void> _waitForRxValue(Rx<String> value, String expected) async {
  if (value.value == expected) return;
  await _waitForStringValue(
    current: () => value.value,
    expected: expected,
    label: 'GetX async',
  );
}

Future<void> _waitForStringValue({
  required String Function() current,
  required String expected,
  required String label,
}) async {
  for (int attempts = 0; attempts < 1000; attempts++) {
    if (current() == expected) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('$label did not settle to $expected (got ${current()})');
}
