import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'process_runner.dart';

typedef JsonMap = Map<String, dynamic>;

ArgResults? parseOptions(List<String> args, ArgParser parser, String usage) {
  parser.addFlag('help', abbr: 'h', negatable: false);
  if (args.contains('--help') || args.contains('-h')) {
    print('$usage\n${parser.usage}');
    return null;
  }
  try {
    return parser.parse(args);
  } on FormatException catch (error) {
    stderr.writeln('${error.message}\n$usage\n${parser.usage}');
    exitCode = 64;
    return null;
  }
}

void requireCondition(bool condition, String message) {
  if (!condition) throw StateError(message);
}

JsonMap readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as JsonMap;

void writeJson(String path, Object? value) {
  final encoded = const JsonEncoder.withIndent('  ').convert(value);
  File(path).writeAsStringSync('$encoded\n');
}

String fileDigest(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

String manifestDigest(Map<String, String> files) => sha256
    .convert(utf8.encode(jsonEncode(SplayTreeMap<String, String>.of(files))))
    .toString();

Iterable<File> sourceFiles(Directory directory) sync* {
  if (!directory.existsSync()) return;
  for (final entry in directory.listSync(followLinks: false)) {
    if (entry is Directory) {
      if (const {
        'build',
        '.dart_tool',
        'Pods',
        'ephemeral',
        '.symlinks',
      }.contains(p.basename(entry.path))) {
        continue;
      }
      yield* sourceFiles(entry);
    } else if (entry is File) {
      yield entry;
    }
  }
}

Map<String, String> sourceManifest(String root) {
  final files = SplayTreeMap<String, String>();
  for (final folder in ['packages', 'benchmarks']) {
    for (final file in sourceFiles(Directory(p.join(root, folder)))) {
      final relative = p.relative(file.path, from: root);
      final name = p.basename(relative);
      if ((name.endsWith('.dart') && p.split(relative).contains('lib')) ||
          const {
            'pubspec.yaml',
            'pubspec.lock',
            'pubspec_overrides.yaml',
          }.contains(name)) {
        files[relative] = fileDigest(file.path);
      }
    }
  }
  return files;
}

String appBinary(String root, String mode) => p.join(
  root,
  'benchmarks',
  'build',
  'macos',
  'Build',
  'Products',
  '${mode[0].toUpperCase()}${mode.substring(1)}',
  'benchmarks.app',
  'Contents',
  'MacOS',
  'benchmarks',
);

String appAot(String binary) =>
    p.join(p.dirname(p.dirname(binary)), 'Frameworks', 'App.framework', 'App');

Future<ProcessOutcome> runLogged(
  List<String> command,
  String logPath, {
  required String workingDirectory,
  Duration timeout = const Duration(minutes: 10),
  Map<String, String>? environment,
}) async {
  final result = await runProcess(
    command,
    workingDirectory: workingDirectory,
    timeout: timeout,
    environment: environment,
    includeParentEnvironment: environment == null,
  );
  File(logPath).writeAsStringSync('${result.stdout}${result.stderr}');
  requireCondition(!result.timedOut, 'Command timed out. Inspect $logPath');
  requireCondition(
    result.exitCode == 0,
    'Command exited ${result.exitCode}. Inspect $logPath',
  );
  return result;
}

JsonMap extractReport(String output, String marker) {
  final lines = const LineSplitter()
      .convert(output)
      .where((line) => line.contains(marker))
      .toList();
  requireCondition(lines.length == 1, 'Expected one complete $marker report');
  return jsonDecode(
        lines.single.substring(lines.single.indexOf(marker) + marker.length),
      )
      as JsonMap;
}

double median(List<dynamic> samples) {
  requireCondition(samples.isNotEmpty, 'Cannot summarize an empty sample set');
  final sorted = samples.cast<num>().toList()..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle].toDouble()
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

num percentile95(List<dynamic> samples) {
  requireCondition(samples.isNotEmpty, 'Cannot summarize an empty sample set');
  final sorted = samples.cast<num>().toList()..sort();
  return sorted[(sorted.length * .95).ceil() - 1];
}

double? percentChange(num before, num after) =>
    before == 0 ? null : 100 * (after / before - 1);

bool sameJson(Object? first, Object? second) {
  if (first is Map && second is Map) {
    return first.length == second.length &&
        first.keys.every(
          (key) => second.containsKey(key) && sameJson(first[key], second[key]),
        );
  }
  if (first is List && second is List) {
    return first.length == second.length &&
        first.asMap().entries.every(
          (entry) => sameJson(entry.value, second[entry.key]),
        );
  }
  return first == second;
}
