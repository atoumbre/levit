import 'dart:io';

import 'src/process_runner.dart';

Future<void> main(List<String> args) async {
  final rootDir = Directory.current;
  final quiet = args.contains('--quiet');
  final onlyPackages = _parseCsvArg(args, '--only');
  final targetPaths = args.where((arg) => !arg.startsWith('--')).toList()
    ..removeWhere((arg) => arg.trim().isEmpty);

  if (targetPaths.isEmpty) {
    targetPaths.add('packages');
  }

  final packages = _discoverPublishablePackages(
    rootDir: rootDir,
    targetPaths: targetPaths,
    onlyPackages: onlyPackages,
  );

  if (packages.isEmpty) {
    print('No publishable packages found.');
    return;
  }

  if (!quiet) {
    print(
      'Publish dry-run packages: ${packages.map((package) => package.name).join(', ')}',
    );
  }

  var failed = false;
  for (final package in packages) {
    if (!quiet) {
      print('[${package.name}] Running publish dry-run...');
    }

    final command = package.isFlutterPackage
        ? ['flutter', 'pub', 'publish', '--dry-run']
        : ['dart', 'pub', 'publish', '--dry-run'];
    final result = await runProcess(
      command,
      workingDirectory: package.directory.path,
      timeout: const Duration(minutes: 2),
    );

    if (result.timedOut) {
      print('[${package.name}] Publish dry-run timed out.');
      failed = true;
      continue;
    }

    if (result.exitCode != 0) {
      print('[${package.name}] Publish dry-run failed.');
      _printCapturedOutput(result);
      failed = true;
      continue;
    }

    if (!quiet) {
      print('[${package.name}] Publish dry-run passed.');
    }
  }

  if (failed) {
    print('Publish dry-run checks failed.');
    exit(1);
  }

  print('Publish dry-run passed for ${packages.length} package(s).');
}

List<_PackageInfo> _discoverPublishablePackages({
  required Directory rootDir,
  required List<String> targetPaths,
  required List<String>? onlyPackages,
}) {
  final onlySet = onlyPackages?.toSet();
  final packages = <_PackageInfo>[];
  final seen = <String>{};

  for (final targetPath in targetPaths) {
    final directory = Directory('${rootDir.path}/$targetPath');
    if (!directory.existsSync()) continue;

    final candidates = <Directory>[];
    if (File('${directory.path}/pubspec.yaml').existsSync()) {
      candidates.add(directory);
    }
    candidates.addAll(
      directory
          .listSync(recursive: true, followLinks: false)
          .whereType<Directory>()
          .where((dir) => File('${dir.path}/pubspec.yaml').existsSync()),
    );

    for (final candidate in candidates) {
      if (!seen.add(candidate.path)) continue;
      if (_isExamplePath(candidate.path)) continue;

      final pubspec = File('${candidate.path}/pubspec.yaml');
      final content = pubspec.readAsStringSync();
      if (_isPrivatePackage(content)) continue;

      final name = _readPubspecScalar(content, 'name');
      if (name == null || name.isEmpty) continue;
      if (onlySet != null &&
          !onlySet.contains(name) &&
          !onlySet.contains(candidate.path)) {
        continue;
      }

      packages.add(
        _PackageInfo(
          name: name,
          directory: candidate,
          isFlutterPackage: _isFlutterPackage(content),
        ),
      );
    }
  }

  packages.sort((a, b) => a.name.compareTo(b.name));
  return packages;
}

bool _isExamplePath(String path) {
  final parts = path.split(Platform.pathSeparator);
  return parts.contains('example') || parts.contains('examples');
}

bool _isPrivatePackage(String pubspec) {
  final publishTo = _readPubspecScalar(pubspec, 'publish_to');
  return publishTo == 'none' || publishTo == "'none'" || publishTo == '"none"';
}

bool _isFlutterPackage(String pubspec) {
  return RegExp(r'^\s*sdk:\s*flutter\s*$', multiLine: true).hasMatch(pubspec) ||
      RegExp(r'^\s*flutter:\s*$', multiLine: true).hasMatch(pubspec);
}

String? _readPubspecScalar(String pubspec, String key) {
  final match =
      RegExp('^$key:\\s*(.+?)\\s*\$', multiLine: true).firstMatch(pubspec);
  return match?.group(1)?.trim();
}

List<String>? _parseCsvArg(List<String> args, String key) {
  final prefix = '$key=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      final value = arg.substring(prefix.length).trim();
      if (value.isEmpty) return null;
      return value
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }
  }
  return null;
}

void _printCapturedOutput(ProcessOutcome result) {
  if (result.stdout.trim().isNotEmpty) {
    print(result.stdout.trimRight());
  }
  if (result.stderr.trim().isNotEmpty) {
    print(result.stderr.trimRight());
  }
}

class _PackageInfo {
  final String name;
  final Directory directory;
  final bool isFlutterPackage;

  const _PackageInfo({
    required this.name,
    required this.directory,
    required this.isFlutterPackage,
  });
}
