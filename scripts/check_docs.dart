import 'dart:io';

import 'src/process_runner.dart';

const _docPackages = <String>[
  'packages/core/levit_reactive',
  'packages/core/levit_scope',
  'packages/core/levit_dart_core',
  'packages/core/levit_flutter_core',
  'packages/core/levit_monitor',
  'packages/kits/levit_dart',
  'packages/kits/levit',
  'packages/kits/levit_flutter',
  'packages/tools/levit_lints',
  'packages/tools/levit_mcp',
  'packages/tools/levit_devtools',
];

Future<void> main(List<String> args) async {
  final rootDir = Directory.current;
  final targets = args.where((a) => !a.startsWith('--')).toList();
  final packages = targets.isEmpty ? _docPackages : targets;

  final tempRoot = Directory.systemTemp.createTempSync('levit_dartdoc_');
  var failed = false;
  try {
    for (final relativePath in packages) {
      final dir = Directory('${rootDir.path}/$relativePath');
      if (!dir.existsSync()) {
        stderr.writeln('Package directory not found: $relativePath');
        failed = true;
        continue;
      }

      final pkgName = relativePath.split('/').last;
      final outDir = Directory('${tempRoot.path}/$pkgName');
      stdout.writeln('[$relativePath] Validating dartdoc...');
      final result = await runProcess(
        ['dart', 'doc', '--validate-links', '--output=${outDir.path}'],
        workingDirectory: dir.path,
        timeout: const Duration(minutes: 5),
      );

      if (result.timedOut) {
        stderr.writeln('[$relativePath] dart doc timed out.');
        failed = true;
        continue;
      }

      final combined = '${result.stdout}\n${result.stderr}';
      final hasWarnings =
          result.exitCode != 0 ||
          RegExp(r'^\s*warning:', multiLine: true).hasMatch(combined);
      if (hasWarnings) {
        stderr.writeln('[$relativePath] dart doc validation failed.');
        if (result.stdout.trim().isNotEmpty) {
          stderr.writeln(result.stdout.trimRight());
        }
        if (result.stderr.trim().isNotEmpty) {
          stderr.writeln(result.stderr.trimRight());
        }
        failed = true;
        continue;
      }

      stdout.writeln('[$relativePath] dart doc passed.');
    }
  } finally {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  }

  if (failed) {
    exit(1);
  }
  stdout.writeln(
    'DartDoc validation passed for ${packages.length} package(s).',
  );
}
