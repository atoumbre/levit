// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Builds and runs `lib/release_performance.dart` in native macOS AOT mode
/// (diagnostics off and on in separate processes) and writes
/// `../reports/release_benchmark_report.md`.
Future<void> main(List<String> args) async {
  if (!Platform.isMacOS) {
    stderr.writeln('Native release benchmark report currently requires macOS.');
    exit(2);
  }

  final profile = args.contains('--profile');
  final mode = profile ? 'profile' : 'release';
  final modeDir = profile ? 'Profile' : 'Release';
  final skipBuild = args.contains('--skip-build');

  if (!skipBuild) {
    print('Building macOS $mode benchmark binary...');
    final build = await Process.run('flutter', [
      'build',
      'macos',
      '--$mode',
      '--target=lib/release_performance.dart',
    ]);
    if (build.exitCode != 0) {
      stderr.writeln(build.stdout);
      stderr.writeln(build.stderr);
      exit(build.exitCode);
    }
  }

  final binaryPath =
      'build/macos/Build/Products/$modeDir/benchmarks.app/Contents/MacOS/benchmarks';
  if (!File(binaryPath).existsSync()) {
    stderr.writeln('Expected benchmark binary not found at $binaryPath');
    exit(1);
  }

  print('Running native $mode workloads (diagnostics=off)...');
  final offPayload = await _runNativeBinary(binaryPath, diagnostics: 'off');

  print('Running native $mode workloads (diagnostics=on)...');
  final onPayload = await _runNativeBinary(binaryPath, diagnostics: 'on');

  final markdown = _renderReport(off: offPayload, on: onPayload);
  final reportFile = File('../reports/release_benchmark_report.md');
  await reportFile.parent.create(recursive: true);
  await reportFile.writeAsString(markdown);
  print('Release benchmark report generated: ${reportFile.absolute.path}');
}

Future<Map<String, dynamic>> _runNativeBinary(
  String binaryPath, {
  required String diagnostics,
}) async {
  final result = await Process.run(
    binaryPath,
    const [],
    environment: {
      ...Platform.environment,
      'LEVIT_PERFORMANCE_RUN': '1',
      'LEVIT_DIAGNOSTICS': diagnostics,
    },
  );
  if (result.exitCode != 0) {
    stderr.writeln('Native benchmark failed (diagnostics=$diagnostics):');
    stderr.writeln(result.stdout);
    stderr.writeln(result.stderr);
    exit(result.exitCode);
  }
  const prefix = 'LEVIT_PERFORMANCE_JSON:';
  final combined = '${result.stdout}\n${result.stderr}';
  for (final line in combined.split('\n')) {
    final index = line.indexOf(prefix);
    if (index != -1) {
      return jsonDecode(line.substring(index + prefix.length).trim())
          as Map<String, dynamic>;
    }
  }
  stderr.writeln('Missing $prefix output for diagnostics=$diagnostics.');
  stderr.writeln(result.stdout);
  exit(1);
}

String _renderReport({
  required Map<String, dynamic> off,
  required Map<String, dynamic> on,
}) {
  final buf = StringBuffer()
    ..writeln('# Native AOT Benchmark Results')
    ..writeln('Generated: ${off['timestamp']}')
    ..writeln()
    ..writeln(
      '> Measured using `benchmarks/lib/release_performance.dart` in native '
      '`${off['mode']}` AOT mode across 3 rounds per diagnostic state '
      '(separate processes). See [`benchmarks/README.md`](../benchmarks/README.md#native-release-comparison) '
      'for methodology details.',
    )
    ..writeln()
    ..writeln('## Environment')
    ..writeln('| Key | Value |')
    ..writeln('|---|---|')
    ..writeln('| Build Mode | `${off['mode']}` (native macOS AOT) |')
    ..writeln('| Dart Runtime | `${off['dart']}` |')
    ..writeln('| Operating System | `${off['os']}` |')
    ..writeln('| CPU Threads | `${off['processors']}` |')
    ..writeln('| Display Refresh Rate (Hz) | `${off['refreshRate']}` |')
    ..writeln(
      '| Activity Guard (`LEVIT_PERFORMANCE_RUN=1`) | `${off['activityGuard']}` |',
    )
    ..writeln();

  final offByWorkload = _groupMeasurements(off);
  final onByWorkload = _groupMeasurements(on);
  final workloads = offByWorkload.keys.toList();

  buf
    ..writeln('## Workload Summary (Diagnostics Off vs. On)')
    ..writeln(
      '| Workload | Diagnostics | Median (µs) | p95 (µs) | Mean (µs) | Min–Max (µs) | Body Median (µs) | Samples | Peak RSS (MB) |',
    )
    ..writeln('|---|---|---:|---:|---:|---|---:|---:|---:|');

  for (final workload in workloads) {
    for (final entry in [
      ('off', offByWorkload[workload]!),
      ('on', onByWorkload[workload]!),
    ]) {
      final samples = <int>[];
      final bodySamples = <int>[];
      var peakRss = 0;
      for (final round in entry.$2) {
        samples.addAll((round['samplesUs'] as List<dynamic>).cast<int>());
        bodySamples.addAll(
          (round['bodySamplesUs'] as List<dynamic>).cast<int>(),
        );
        final rss = round['rssBytes'] as int? ?? 0;
        if (rss > peakRss) peakRss = rss;
      }
      final stats = _Stats.from(samples);
      final bodyStats = _Stats.from(bodySamples);
      final rssMb = (peakRss / (1024 * 1024)).toStringAsFixed(1);
      buf.writeln(
        '| `$workload` | ${entry.$1} | ${stats.median} | ${stats.p95} | '
        '${stats.mean.toStringAsFixed(1)} | ${stats.min}–${stats.max} | '
        '${bodyStats.median} | ${samples.length} | $rssMb |',
      );
    }
  }

  final frameOff = _extractFrameTimings(offByWorkload['list_1000_frame']);
  final frameOn = _extractFrameTimings(onByWorkload['list_1000_frame']);
  if (frameOff.build.isNotEmpty || frameOn.build.isNotEmpty) {
    buf
      ..writeln()
      ..writeln('## Mounted 1,000-Row List Frame Timings (`list_1000_frame`)')
      ..writeln(
        '| Diagnostics | Build p50 (µs) | Build p95 (µs) | Raster p50 (µs) | Raster p95 (µs) | Frames |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|');
    for (final pair in [('off', frameOff), ('on', frameOn)]) {
      final b = _Stats.from(pair.$2.build);
      final r = _Stats.from(pair.$2.raster);
      buf.writeln(
        '| ${pair.$1} | ${b.median} | ${b.p95} | ${r.median} | ${r.p95} | ${pair.$2.build.length} |',
      );
    }
  }

  return buf.toString();
}

Map<String, List<Map<String, dynamic>>> _groupMeasurements(
  Map<String, dynamic> payload,
) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  final list = (payload['measurements'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final item in list) {
    final name = item['workload'] as String;
    grouped.putIfAbsent(name, () => []).add(item);
  }
  return grouped;
}

({List<int> build, List<int> raster}) _extractFrameTimings(
  List<Map<String, dynamic>>? rounds,
) {
  final build = <int>[];
  final raster = <int>[];
  if (rounds == null) return (build: build, raster: raster);
  for (final round in rounds) {
    final frames = round['frameTimings'] as List<dynamic>?;
    if (frames == null) continue;
    for (final frame in frames.cast<Map<String, dynamic>>()) {
      final b = frame['buildUs'] as int?;
      final r = frame['rasterUs'] as int?;
      if (b != null) build.add(b);
      if (r != null) raster.add(r);
    }
  }
  return (build: build, raster: raster);
}

class _Stats {
  final int min;
  final int max;
  final int median;
  final int p95;
  final double mean;

  const _Stats({
    required this.min,
    required this.max,
    required this.median,
    required this.p95,
    required this.mean,
  });

  factory _Stats.from(List<int> values) {
    if (values.isEmpty) {
      return const _Stats(min: 0, max: 0, median: 0, p95: 0, mean: 0);
    }
    final sorted = [...values]..sort();
    final sum = sorted.fold<int>(0, (acc, v) => acc + v);
    final mid = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[mid]
        : ((sorted[mid - 1] + sorted[mid]) / 2).round();
    final p95Index = math.min(
      sorted.length - 1,
      ((sorted.length - 1) * 0.95).ceil(),
    );
    return _Stats(
      min: sorted.first,
      max: sorted.last,
      median: median,
      p95: sorted[p95Index],
      mean: sum / sorted.length,
    );
  }
}
