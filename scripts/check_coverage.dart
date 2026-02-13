import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final rootDir = Directory.current;
  final generateReportFile = args.contains('--generate-report');
  final changedOnly = args.contains('--changed');
  final includeExamples = args.contains('--include-examples');
  final onlyPackages = _parseCsvArg(args, '--only');
  final maxPackages = _parseIntArg(args, '--max-packages');
  final timeoutSeconds = _parseIntArg(args, '--timeout');
  final targetPaths = args.where((arg) => !arg.startsWith('--')).toList();

  if (targetPaths.isEmpty) {
    targetPaths.add('packages');
  }

  print('🔍 Scanning for packages in: ${targetPaths.join(', ')}...');
  if (generateReportFile) {
    print('📝 Report file generation enabled.');
  }
  if (changedOnly) {
    print('🧩 Filtering to changed packages only.');
  }
  if (!includeExamples) {
    print('🙈 Excluding example projects (use --include-examples to include).');
  }
  if (onlyPackages != null && onlyPackages.isNotEmpty) {
    print('🎯 Filtering to packages: ${onlyPackages.join(', ')}');
  }
  if (maxPackages != null) {
    print('⏱️  Limiting to $maxPackages package(s).');
  }
  if (timeoutSeconds != null) {
    print('⏲️  Per-package timeout: ${timeoutSeconds}s');
  }

  final packages = <Directory>[];
  for (final path in targetPaths) {
    final dir = Directory('${rootDir.path}/$path');
    if (!dir.existsSync()) {
      print('⚠️ Warning: Path not found: $path. Skipping.');
      continue;
    }

    bool isExampleDir(String path) {
      if (includeExamples) return false;
      // specific check for path components to avoid accidental partial matches
      final parts = path.split(Platform.pathSeparator);
      return parts.contains('example') || parts.contains('examples');
    }

    // Find all directories in the target path (including itself) that have a pubspec.yaml
    // but exclude .dart_tool and similar internal folders.
    final List<Directory> found = [];
    if (!dir.path.contains('.dart_tool') &&
        File('${dir.path}/pubspec.yaml').existsSync() &&
        !isExampleDir(dir.path)) {
      found.add(dir);
    }

    found.addAll(dir.listSync(recursive: true).whereType<Directory>().where(
        (d) =>
            !d.path.contains('.dart_tool') &&
            File('${d.path}/pubspec.yaml').existsSync() &&
            !isExampleDir(d.path)));

    packages.addAll(found);
  }

  if (packages.isEmpty) {
    print('No packages found in target paths.');
    exit(0);
  }

  // Remove duplicates (just in case)
  final uniquePaths = <String>{};
  packages.retainWhere((dir) => uniquePaths.add(dir.path));

  if (changedOnly) {
    final changedPaths = await _getChangedPaths(rootDir.path);
    if (changedPaths.isEmpty) {
      print('⚠️ Warning: No changed files detected. Skipping.');
      exit(0);
    }
    packages.retainWhere(
        (dir) => changedPaths.any((path) => path.startsWith(dir.path)));
  }

  if (onlyPackages != null && onlyPackages.isNotEmpty) {
    final onlySet = onlyPackages.toSet();
    packages.retainWhere((dir) {
      final name = dir.path.split(Platform.pathSeparator).last;
      return onlySet.contains(name) || onlySet.contains(dir.path);
    });
  }

  if (maxPackages != null && packages.length > maxPackages) {
    packages.removeRange(maxPackages, packages.length);
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

    final timeout =
        timeoutSeconds == null ? null : Duration(seconds: timeoutSeconds);

    // Pure Dart packages should use `dart test` for speed and correctness.
    // Additionally, some tests may import `dart:mirrors`, which is not supported
    // by `flutter test` and can lead to hangs/errors.
    final usesDartMirrors = _usesDartMirrors(testDir);
    final isFlutterPackage = _isFlutterPackage(package);
    final useDartTest = !isFlutterPackage || usesDartMirrors;

    final _ProcessOutcome result;
    if (useDartTest) {
      if (usesDartMirrors) {
        print(
            '🪞 [$packageName] Detected dart:mirrors in tests; using dart test.');
      } else {
        print('🧪 [$packageName] Pure Dart package; using dart test.');
      }
      result = await _runProcess(
        ['dart', 'test', '--coverage=coverage'],
        workingDirectory: package.path,
        timeout: timeout,
      );
      if (!result.timedOut && result.exitCode == 0) {
        final formatResult = await _runProcess(
          [
            'dart',
            'run',
            'coverage:format_coverage',
            '--lcov',
            '--in=coverage',
            '--out=coverage/lcov.info',
            '--packages=.dart_tool/package_config.json',
            '--report-on=lib',
          ],
          workingDirectory: package.path,
          timeout: timeout,
        );
        if (formatResult.timedOut || formatResult.exitCode != 0) {
          print('❌ [$packageName] Coverage formatting failed!');
          print(formatResult.stdout);
          print(formatResult.stderr);
          hasFailures = true;
          continue;
        }
      }
    } else {
      // Run tests with coverage (Flutter runner). We suppress output to keep the
      // terminal clean, unless there's an error.
      result = await _runProcess(
        ['flutter', 'test', '--coverage'],
        workingDirectory: package.path,
        timeout: timeout,
      );
    }

    if (result.timedOut) {
      print(
        '⏱️  [$packageName] Timed out after ${timeoutSeconds}s. Skipping.',
      );
      hasFailures = true;
      continue;
    }
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

    // Fix paths in lcov.info to be relative to repo root for Codecov
    // This allows uploading individual package reports with correct flags.
    // Do this before parsing so report details use normalized paths too.
    _fixLcovPaths(lcovFile, package.path, rootDir.path);

    final packageStats = _parseLcov(lcovFile, packageName);
    stats[packageName] = packageStats;
    globalStats.merge(packageStats);

    print(
      '✅ [$packageName] Done. (${packageStats.coveragePercent.toStringAsFixed(1)}%)',
    );
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

List<String>? _parseCsvArg(List<String> args, String key) {
  final prefix = '$key=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      final value = arg.substring(prefix.length).trim();
      if (value.isEmpty) return null;
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }
  return null;
}

int? _parseIntArg(List<String> args, String key) {
  final prefix = '$key=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      final value = arg.substring(prefix.length).trim();
      if (value.isEmpty) return null;
      return int.tryParse(value);
    }
  }
  return null;
}

Future<Set<String>> _getChangedPaths(String repoRoot) async {
  final result = await Process.run(
    'git',
    ['status', '--porcelain'],
    workingDirectory: repoRoot,
  );

  if (result.exitCode != 0) {
    print('⚠️ Warning: Unable to read git status. Skipping changed filter.');
    return {};
  }

  final paths = <String>{};
  final lines = result.stdout.toString().split('\n');
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    if (line.length < 4) continue;
    var path = line.substring(3).trim();
    if (path.contains('->')) {
      path = path.split('->').last.trim();
    }
    if (path.isEmpty) continue;
    paths.add(Directory('$repoRoot/$path').absolute.path);
  }

  return paths;
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

void _fixLcovPaths(File lcovFile, String packagePath, String rootPath) {
  final content = lcovFile.readAsStringSync();

  // Get relative path from root to package
  // e.g., /user/repo/packages/core/pkg -> packages/core/pkg
  String relativePkgPath = packagePath.replaceFirst(rootPath, '');
  if (relativePkgPath.startsWith(Platform.pathSeparator)) {
    relativePkgPath = relativePkgPath.substring(1);
  }

  // Normalize SF paths so Codecov maps them relative to repo root.
  var fixedContent = content;

  // Flutter runner typically emits SF:lib/...
  fixedContent = fixedContent.replaceAll('SF:lib/', 'SF:$relativePkgPath/lib/');

  // Dart runner (coverage:format_coverage) often emits absolute paths.
  final normalizedPkgPath = packagePath.replaceAll('\\', '/');
  fixedContent = fixedContent.replaceAll(
    'SF:$normalizedPkgPath/lib/',
    'SF:$relativePkgPath/lib/',
  );

  if (fixedContent != content) {
    lcovFile.writeAsStringSync(fixedContent);
  }
}

class _ProcessOutcome {
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;

  _ProcessOutcome({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.timedOut,
  });
}

Future<_ProcessOutcome> _runProcess(
  List<String> command, {
  required String workingDirectory,
  Duration? timeout,
}) async {
  final process = await Process.start(
    command.first,
    command.sublist(1),
    workingDirectory: workingDirectory,
  );

  final stdoutFuture = process.stdout.transform(utf8.decoder).join();
  final stderrFuture = process.stderr.transform(utf8.decoder).join();

  int exitCode;
  bool timedOut = false;
  try {
    exitCode = timeout == null
        ? await process.exitCode
        : await process.exitCode.timeout(timeout);
  } on TimeoutException {
    timedOut = true;
    process.kill(ProcessSignal.sigterm);
    exitCode = -1;
  }

  final stdout = await stdoutFuture;
  final stderr = await stderrFuture;

  return _ProcessOutcome(
    exitCode: exitCode,
    stdout: stdout,
    stderr: stderr,
    timedOut: timedOut,
  );
}

bool _usesDartMirrors(Directory testDir) {
  try {
    for (final entity
        in testDir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      if (content.contains("import 'dart:mirrors'") ||
          content.contains('import "dart:mirrors"')) {
        return true;
      }
    }
  } catch (_) {
    // Best-effort detection. If anything goes wrong, default to flutter runner.
  }
  return false;
}

bool _isFlutterPackage(Directory packageDir) {
  final pubspec = File('${packageDir.path}/pubspec.yaml');
  if (!pubspec.existsSync()) return true;
  try {
    final content = pubspec.readAsStringSync();
    return RegExp(r'^\s*sdk:\s*flutter\s*$', multiLine: true)
            .hasMatch(content) ||
        RegExp(r'^\s*flutter:\s*$', multiLine: true).hasMatch(content);
  } catch (_) {
    return true;
  }
}
