import 'dart:io';
import 'src/process_runner.dart';

/// Compile the supported Dart/browser surfaces and runnable Flutter workflows.
/// Build checks do not replace interactive browser acceptance or performance runs.
Future<void> main() async {
  final root = Directory.current.path;
  final output = Directory('$root/build/browser_contracts')
    ..createSync(recursive: true);
  final checks = <(String, List<String>)>[
    (
      'packages/kits/levit',
      [
        'dart',
        'compile',
        'js',
        'tool/browser_contract.dart',
        '-o',
        '${output.path}/levit.js',
      ],
    ),
    (
      'examples/async_catalog',
      ['flutter', 'build', 'web', '--release', '--no-web-resources-cdn'],
    ),
    (
      'examples/task_board',
      [
        'flutter',
        'build',
        'web',
        '--release',
        '--no-web-resources-cdn',
        '-t',
        'lib/save_upload.dart',
      ],
    ),
    (
      'examples/scope_playground',
      [
        'flutter',
        'build',
        'web',
        '--release',
        '--no-web-resources-cdn',
        '-t',
        'lib/session_replacement.dart',
      ],
    ),
    ('.', ['dart', 'run', 'scripts/build_devtools.dart']),
  ];
  for (final (path, command) in checks) {
    print('Browser contract: $path');
    final result = await runProcess(
      command,
      workingDirectory: '$root/$path',
      timeout: const Duration(minutes: 10),
    );
    if (result.timedOut || result.exitCode != 0) {
      stderr.writeln('${result.stdout}\n${result.stderr}');
      exit(1);
    }
    print('Passed: $path');
  }
}
