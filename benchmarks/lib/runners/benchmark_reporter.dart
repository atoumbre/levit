import '../benchmark_environment.dart';
import '../benchmark_engine.dart';

class BenchmarkReporter {
  /// Generates a Markdown report from a map of benchmark results.
  static String generateMarkdownReport({
    required Map<String, List<BenchmarkResult>> results,
    String? title,
    BenchmarkEnvironment? environment,
  }) {
    final buffer = StringBuffer();
    if (title != null) {
      buffer.writeln('# $title');
    } else {
      buffer.writeln('# Benchmark Results');
    }
    buffer.writeln('Date: ${environment?.capturedAt ?? DateTime.now()}');
    buffer.writeln('');
    if (environment != null) {
      _writeMarkdownEnvironment(buffer, environment);
    }

    for (final benchName in results.keys) {
      final benchmarkResults = results[benchName]!;
      final lead = benchmarkResults.first;
      buffer.writeln('## $benchName');
      buffer.writeln(
          'Classification: ${lead.classification.label}${lead.comparisonNote == null ? '' : '  \nNote: ${lead.comparisonNote}'}');
      buffer.writeln(
          '| Framework | Median (µs) | Mean (µs) | Min-Max (µs) | StdDev (µs) | Samples | Status |');
      buffer.writeln('|---|---|---|---|---|---|---|');

      final sortedResults = List<BenchmarkResult>.from(benchmarkResults)
        ..sort((a, b) => a.durationMicros.compareTo(b.durationMicros));

      for (final res in sortedResults) {
        final status = res.success ? 'OK' : 'Error: ${res.error}';
        final range = '${res.minMicros}-${res.maxMicros}';
        buffer.writeln('| ${res.framework.label} '
            '| ${res.durationMicros} '
            '| ${res.meanMicros.toStringAsFixed(1)} '
            '| $range '
            '| ${res.stdDevMicros.toStringAsFixed(1)} '
            '| ${res.iterations} '
            '| $status |');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// Generates a console-friendly report with aligned columns.
  static String generateConsoleReport({
    required Map<String, List<BenchmarkResult>> results,
    String? title,
    BenchmarkEnvironment? environment,
  }) {
    final buffer = StringBuffer();
    final line = '=' * 80;
    final thinLine = '-' * 80;

    buffer.writeln('\n$line');
    buffer.writeln(title?.toUpperCase() ?? 'BENCHMARK RESULTS');
    buffer.writeln('Date: ${environment?.capturedAt ?? DateTime.now()}');
    buffer.writeln('$line\n');
    if (environment != null) {
      _writeConsoleEnvironment(buffer, environment, line, thinLine);
    }

    for (final benchName in results.keys) {
      final benchmarkResults = results[benchName]!;
      final lead = benchmarkResults.first;
      buffer.writeln('>>> $benchName');
      buffer.writeln(thinLine);
      buffer.writeln(
          'Class: ${lead.classification.label}${lead.comparisonNote == null ? '' : ' | Note: ${lead.comparisonNote}'}');
      buffer.writeln(thinLine);
      buffer.writeln(
          '${'Framework'.padRight(15)} | ${'Median µs'.padRight(10)} | ${'Mean µs'.padRight(10)} | ${'Min-Max µs'.padRight(17)} | ${'StdDev'.padRight(10)} | ${'N'.padRight(3)} | Status');
      buffer.writeln(thinLine);

      final sortedResults = List<BenchmarkResult>.from(benchmarkResults)
        ..sort((a, b) => a.durationMicros.compareTo(b.durationMicros));

      for (final res in sortedResults) {
        final status =
            res.success ? 'OK' : 'ERROR: ${res.error?.split('\n').first}';
        buffer.writeln('${res.framework.label.padRight(15)} | '
            '${res.durationMicros.toString().padRight(10)} | '
            '${res.meanMicros.toStringAsFixed(1).padRight(10)} | '
            '${'${res.minMicros}-${res.maxMicros}'.padRight(17)} | '
            '${res.stdDevMicros.toStringAsFixed(1).padRight(10)} | '
            '${res.iterations.toString().padRight(3)} | '
            '$status');
      }
      buffer.writeln('$line\n');
    }

    return buffer.toString();
  }

  static void _writeMarkdownEnvironment(
    StringBuffer buffer,
    BenchmarkEnvironment environment,
  ) {
    buffer.writeln('## Environment');
    buffer.writeln('| Key | Value |');
    buffer.writeln('|---|---|');

    final rows = <MapEntry<String, String>>[
      MapEntry('Execution Context', environment.executionContext),
      MapEntry('Build Mode', environment.buildMode),
      MapEntry('Benchmark Profile', environment.benchmarkProfile),
      MapEntry('Iterations', environment.iterations.toString()),
      MapEntry('Warmup Iterations', environment.warmupIterations.toString()),
      MapEntry(
        'Framework Order Rotation',
        environment.frameworkOrderRotation ? 'Enabled' : 'Disabled',
      ),
      MapEntry('Frameworks', environment.frameworks.join(', ')),
      MapEntry('Benchmarks', environment.benchmarks.join(', ')),
      MapEntry('Operating System', environment.operatingSystem),
      MapEntry('OS Version', environment.operatingSystemVersion),
      MapEntry('Dart Version', environment.dartVersion),
      MapEntry('CPU Threads', environment.processorCount.toString()),
      MapEntry('Locale', environment.locale),
    ];

    if (environment.hostName case final hostName?) {
      rows.add(MapEntry('Host Name', hostName));
    }

    if (environment.displayMetrics case final display?) {
      rows.add(MapEntry(
        'Display',
        '${display.logicalSizeLabel} logical, ${display.physicalSizeLabel} physical @ ${display.devicePixelRatio.toStringAsFixed(2)}x',
      ));
    }

    for (final row in rows) {
      buffer.writeln('| ${row.key} | ${row.value} |');
    }

    buffer.writeln('');
  }

  static void _writeConsoleEnvironment(
    StringBuffer buffer,
    BenchmarkEnvironment environment,
    String line,
    String thinLine,
  ) {
    buffer.writeln('ENVIRONMENT');
    buffer.writeln(thinLine);

    final rows = <String, String>{
      'Execution Context': environment.executionContext,
      'Build Mode': environment.buildMode,
      'Benchmark Profile': environment.benchmarkProfile,
      'Iterations': environment.iterations.toString(),
      'Warmup Iterations': environment.warmupIterations.toString(),
      'Framework Order Rotation':
          environment.frameworkOrderRotation ? 'Enabled' : 'Disabled',
      'Frameworks': environment.frameworks.join(', '),
      'Benchmarks': environment.benchmarks.join(', '),
      'Operating System': environment.operatingSystem,
      'OS Version': environment.operatingSystemVersion,
      'Dart Version': environment.dartVersion,
      'CPU Threads': environment.processorCount.toString(),
      'Locale': environment.locale,
    };

    if (environment.hostName case final hostName?) {
      rows['Host Name'] = hostName;
    }

    if (environment.displayMetrics case final display?) {
      rows['Display'] =
          '${display.logicalSizeLabel} logical, ${display.physicalSizeLabel} physical @ ${display.devicePixelRatio.toStringAsFixed(2)}x';
    }

    for (final row in rows.entries) {
      buffer.writeln('${row.key.padRight(24)} : ${row.value}');
    }

    buffer.writeln('$line\n');
  }
}
