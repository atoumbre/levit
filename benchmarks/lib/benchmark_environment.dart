import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'benchmark_engine.dart';

class BenchmarkDisplayMetrics {
  final double logicalWidth;
  final double logicalHeight;
  final double physicalWidth;
  final double physicalHeight;
  final double devicePixelRatio;

  const BenchmarkDisplayMetrics({
    required this.logicalWidth,
    required this.logicalHeight,
    required this.physicalWidth,
    required this.physicalHeight,
    required this.devicePixelRatio,
  });

  String get logicalSizeLabel =>
      '${logicalWidth.toStringAsFixed(0)}x${logicalHeight.toStringAsFixed(0)}';

  String get physicalSizeLabel =>
      '${physicalWidth.toStringAsFixed(0)}x${physicalHeight.toStringAsFixed(0)}';
}

class BenchmarkEnvironment {
  final DateTime capturedAt;
  final String executionContext;
  final String buildMode;
  final String benchmarkProfile;
  final int iterations;
  final int warmupIterations;
  final List<String> frameworks;
  final List<String> benchmarks;
  final bool frameworkOrderRotation;
  final String operatingSystem;
  final String operatingSystemVersion;
  final String dartVersion;
  final int processorCount;
  final String locale;
  final String? hostName;
  final BenchmarkDisplayMetrics? displayMetrics;

  const BenchmarkEnvironment({
    required this.capturedAt,
    required this.executionContext,
    required this.buildMode,
    required this.benchmarkProfile,
    required this.iterations,
    required this.warmupIterations,
    required this.frameworks,
    required this.benchmarks,
    required this.frameworkOrderRotation,
    required this.operatingSystem,
    required this.operatingSystemVersion,
    required this.dartVersion,
    required this.processorCount,
    required this.locale,
    required this.hostName,
    required this.displayMetrics,
  });

  static BenchmarkEnvironment capture({
    required String executionContext,
    required String benchmarkProfile,
    required int iterations,
    required int warmupIterations,
    required Iterable<Framework> frameworks,
    required Iterable<Benchmark> benchmarks,
    bool frameworkOrderRotation = false,
    bool includeHostName = true,
  }) {
    final dispatcher = _maybePlatformDispatcher();
    final view = dispatcher == null
        ? null
        : dispatcher.implicitView ??
            (dispatcher.views.isNotEmpty ? dispatcher.views.first : null);

    return BenchmarkEnvironment(
      capturedAt: DateTime.now(),
      executionContext: executionContext,
      buildMode: _buildModeLabel(),
      benchmarkProfile: benchmarkProfile,
      iterations: iterations,
      warmupIterations: warmupIterations,
      frameworks: frameworks.map((framework) => framework.label).toList(),
      benchmarks: benchmarks.map((benchmark) => benchmark.name).toList(),
      frameworkOrderRotation: frameworkOrderRotation,
      operatingSystem: Platform.operatingSystem,
      operatingSystemVersion: Platform.operatingSystemVersion,
      dartVersion: Platform.version.split(' ').first,
      processorCount: Platform.numberOfProcessors,
      locale: dispatcher?.locale.toLanguageTag() ?? Platform.localeName,
      hostName: includeHostName ? _safeHostName() : null,
      displayMetrics: view == null
          ? null
          : BenchmarkDisplayMetrics(
              logicalWidth: view.physicalSize.width / view.devicePixelRatio,
              logicalHeight: view.physicalSize.height / view.devicePixelRatio,
              physicalWidth: view.physicalSize.width,
              physicalHeight: view.physicalSize.height,
              devicePixelRatio: view.devicePixelRatio,
            ),
    );
  }
}

PlatformDispatcher? _maybePlatformDispatcher() {
  try {
    return WidgetsBinding.instance.platformDispatcher;
  } catch (_) {
    return null;
  }
}

String _buildModeLabel() {
  if (kReleaseMode) return 'release';
  if (kProfileMode) return 'profile';
  return 'debug';
}

String? _safeHostName() {
  try {
    return Platform.localHostname;
  } catch (_) {
    return null;
  }
}
