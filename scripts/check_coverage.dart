import 'dart:io';

Future<void> main(List<String> args) async {
  final rootDir = Directory.current;
  final packagesDir = Directory('${rootDir.path}/packages');
  final generateReportFile = args.contains('--generate-report');

  print('🔍 Scanning for packages in ${packagesDir.path}...');
  if (generateReportFile) {
    print('📝 Report file generation enabled.');
  }

  if (!packagesDir.existsSync()) {
    print('Error: packages/ directory not found at ${packagesDir.path}');
    exit(1);
  }

  // Find all directories in packages/ that have a pubspec.yaml
  final packages = packagesDir.listSync().whereType<Directory>().where((dir) {
    return File('${dir.path}/pubspec.yaml').existsSync();
  }).toList();

  if (packages.isEmpty) {
    print('No packages found in packages/');
    exit(0);
  }

  print(
    'Found ${packages.length} packages: ${packages.map((d) => d.path.split(Platform.pathSeparator).last).join(', ')}\n',
  );

  final stats = <String, PackageStats>{};
  final globalStats = PackageStats('GLOBAL');
  bool hasFailures = false;

  for (final package in packages) {
    final packageName = package.path.split(Platform.pathSeparator).last;
    print('📦 [$packageName] Running tests and generating coverage...');

    final testDir = Directory('${package.path}/test');
    if (!testDir.existsSync()) {
      print('⚠️ [$packageName] No test/ directory found. Skipping.');
      continue;
    }

    // Check if there are any actual test files
    final hasTestFiles = testDir
        .listSync(recursive: true)
        .any((f) => f is File && f.path.endsWith('_test.dart'));

    if (!hasTestFiles) {
      print(
        '⚠️ [$packageName] test/ directory exists but contains no _test.dart files. Skipping.',
      );
      continue;
    }

    // Run tests with coverage
    // We suppress output to keep the terminal clean, unless there's an error
    final result = await Process.run(
        'flutter',
        [
          'test',
          '--coverage',
        ],
        workingDirectory: package.path);
    if (result.exitCode != 0) {
      print('❌ [$packageName] Tests failed!');
      print(result.stdout);
      print(result.stderr);
      hasFailures = true;
      continue;
    }

    final lcovFile = File('${package.path}/coverage/lcov.info');
    if (!lcovFile.existsSync()) {
      print(
        '⚠️ [$packageName] No coverage/lcov.info file generated (Maybe no tests?).',
      );
      continue;
    }

    final packageStats = _parseLcov(lcovFile, packageName);
    stats[packageName] = packageStats;
    globalStats.merge(packageStats);

    print(
      '✅ [$packageName] Done. (${packageStats.coveragePercent.toStringAsFixed(1)}%)',
    );

    // Fix paths in lcov.info to be relative to repo root for Codecov
    // This allows uploading individual package reports with correct flags
    _fixLcovPaths(lcovFile, package.path);
  }

  // --- REPORT ---
  await _generateReport(stats, globalStats, generateReportFile);

  if (hasFailures) {
    print('\n❌ Some tests failed. Check logs above.');
    exit(1);
  }
}

Future<void> _generateReport(
  Map<String, PackageStats> stats,
  PackageStats globalStats,
  bool generateFile,
) async {
  final buffer = StringBuffer();
  buffer.writeln('# 📊 Levit Coverage Report');
  buffer.writeln();
  buffer.writeln(
    '> **Generated on:** ${DateTime.now().toIso8601String().split('T')[0]}',
  );
  buffer.writeln();
  buffer.writeln('| Package | Lines Covered | Total Lines | Coverage |');
  buffer.writeln('| :--- | :--- | :--- | :--- |');

  for (final pkg in stats.keys.toList()..sort()) {
    final s = stats[pkg]!;
    buffer.writeln(
      '| $pkg | ${s.coveredLines} | ${s.totalLines} | **${s.coveragePercent.toStringAsFixed(2)}%** |',
    );
  }

  buffer.writeln('| --- | --- | --- | --- |');
  buffer.writeln(
    '| **GLOBAL** | **${globalStats.coveredLines}** | **${globalStats.totalLines}** | **${globalStats.coveragePercent.toStringAsFixed(2)}%** |',
  );
  buffer.writeln();

  // Show uncovered details
  buffer.writeln('## 📝 Uncovered Lines Details');
  buffer.writeln();

  bool flawless = true;
  for (final pkg in stats.keys.toList()..sort()) {
    final s = stats[pkg]!;
    if (s.coveragePercent < 100) {
      flawless = false;
      buffer.writeln('### 📦 $pkg');
      buffer.writeln();
      if (s.uncoveredFiles.isEmpty) {
        buffer.writeln('_No detailed info available_');
      } else {
        s.uncoveredFiles.forEach((file, lines) {
          // Formatting
          final ranges = <String>[];
          if (lines.isNotEmpty) {
            lines.sort();
            int start = lines.first;
            int end = lines.first;
            for (int i = 1; i < lines.length; i++) {
              if (lines[i] == end + 1) {
                end = lines[i];
              } else {
                ranges.add(start == end ? '$start' : '$start-$end');
                start = lines[i];
                end = lines[i];
              }
            }
            ranges.add(start == end ? '$start' : '$start-$end');
          }
          buffer.writeln('- `$file`: ${ranges.join(', ')}');
        });
      }
      buffer.writeln();
    }
  }

  if (flawless) {
    buffer.writeln('✨ **Perfect coverage across all packages!**');
  }

  // Console Output (reuse existing logic but simplified)
  print('\n${'=' * 65}');
  print('📊 LEVIT COVERAGE REPORT');
  print('=' * 65);
  print('| Package              | Lines Covered | Total Lines | Coverage |');
  print('|----------------------|---------------|-------------|----------|');

  for (final pkg in stats.keys.toList()..sort()) {
    final s = stats[pkg]!;
    print(
      '| ${pkg.padRight(20)} | ${s.coveredLines.toString().padLeft(13)} | ${s.totalLines.toString().padLeft(11)} | ${s.coveragePercent.toStringAsFixed(2).padLeft(7)}% |',
    );
  }

  print('-' * 65);
  print(
    '| ${"GLOBAL".padRight(20)} | ${globalStats.coveredLines.toString().padLeft(13)} | ${globalStats.totalLines.toString().padLeft(11)} | ${globalStats.coveragePercent.toStringAsFixed(2).padLeft(7)}% |',
  );
  print('=' * 65);

  // Print Uncovered Lines Details to Console
  if (!flawless) {
    print('\n📝 Uncovered Lines Details:');
    for (final pkg in stats.keys.toList()..sort()) {
      final s = stats[pkg]!;
      if (s.coveragePercent < 100) {
        print('\n📦 $pkg');
        if (s.uncoveredFiles.isEmpty) {
          print('  _No detailed info available_');
        } else {
          s.uncoveredFiles.forEach((file, lines) {
            final ranges = <String>[];
            if (lines.isNotEmpty) {
              lines.sort();
              int start = lines.first;
              int end = lines.first;
              for (int i = 1; i < lines.length; i++) {
                if (lines[i] == end + 1) {
                  end = lines[i];
                } else {
                  ranges.add(start == end ? '$start' : '$start-$end');
                  start = lines[i];
                  end = lines[i];
                }
              }
              ranges.add(start == end ? '$start' : '$start-$end');
            }
            print('  • $file: ${ranges.join(', ')}');
          });
        }
      }
    }
    print('\n${'=' * 65}');
  }

  // Export to file ONLY if requested
  if (generateFile) {
    final reportsDir = Directory('reports');
    if (!reportsDir.existsSync()) {
      reportsDir.createSync();
    }

    final reportFile = File('reports/packages_test_coverage.md');
    await reportFile.writeAsString(buffer.toString());
    print('\n✅ Report exported to: ${reportFile.absolute.path}');
  } else {
    print(
        '\nℹ️  Skipped report file generation (use --generate-report to enable)');
  }
}

class PackageStats {
  final String name;
  int totalLines = 0;
  int coveredLines = 0;
  final Map<String, List<int>> uncoveredFiles = {};

  PackageStats(this.name);

  double get coveragePercent =>
      totalLines == 0 ? 100.0 : (coveredLines / totalLines * 100);

  void merge(PackageStats other) {
    totalLines += other.totalLines;
    coveredLines += other.coveredLines;
    // We don't merge detailed file info for global stats to keep it simple,
    // or we could but it might be messy. Keeping detailed info per-package is better.
  }
}

PackageStats _parseLcov(File file, String packageName) {
  final stats = PackageStats(packageName);

  if (!file.existsSync()) return stats;

  final lines = file.readAsLinesSync();
  // FilePath -> Map<LineNumber, Hits>
  final fileHits = <String, Map<int, int>>{};
  String? currentFile;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      // SF:lib/src/file.dart
      // We only want to count lines in lib/, explicitly excluding generated code.
      final path = line.substring(3);
      if (path.contains('lib/') &&
          !path.endsWith('.g.dart') &&
          !path.endsWith('.freezed.dart')) {
        currentFile = path;
      } else {
        currentFile = null;
      }
    } else if (currentFile != null && line.startsWith('DA:')) {
      // DA:line,hits
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        final lineNum = int.parse(parts[0]);
        final hits = int.parse(parts[1]);

        // Merge hits: ensure we track the line, adding hits if it appears multiple times
        final lineMap = fileHits.putIfAbsent(currentFile, () => {});
        lineMap[lineNum] = (lineMap[lineNum] ?? 0) + hits;
      }
    }
  }

  // Calculate stats from the aggregated data
  for (final entry in fileHits.entries) {
    final filePath = entry.key;
    final lineMap = entry.value;

    for (final lineEntry in lineMap.entries) {
      final lineNum = lineEntry.key;
      final hits = lineEntry.value;

      stats.totalLines++;
      if (hits > 0) {
        stats.coveredLines++;
      } else {
        stats.uncoveredFiles.putIfAbsent(filePath, () => []).add(lineNum);
      }
    }
  }

  return stats;
}

void _fixLcovPaths(File lcovFile, String packagePath) {
  final content = lcovFile.readAsStringSync();
  // Get package name from directory path
  final packageName = packagePath.split(Platform.pathSeparator).last;
  final relativePkgPath = 'packages/$packageName';

  // Replace SF:lib/ with SF:packages/pkg_name/lib/
  // This ensures Codecov maps it correctly to the repo root
  if (content.contains('SF:lib/')) {
    final fixedContent =
        content.replaceAll('SF:lib/', 'SF:$relativePkgPath/lib/');
    lcovFile.writeAsStringSync(fixedContent);
    // Silent fix to avoid clutter
  }
}
