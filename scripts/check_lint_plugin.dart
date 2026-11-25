import 'dart:io';

/// Exercises the native analysis-server plugin through dart analyze in a real
/// consumer, with local runtime dependencies and an unpublished plugin path.
Future<void> main() async {
  final root = Directory.current.absolute.path;
  final temporary = await Directory.systemTemp.createTemp(
    'levit-lint-consumer-',
  );
  try {
    await File('${temporary.path}/pubspec.yaml').writeAsString('''
name: levit_lint_consumer
publish_to: none
environment:
  sdk: ^3.12.0
dependencies:
  levit:
    path: $root/packages/kits/levit
dependency_overrides:
  levit_dart:
    path: $root/packages/kits/levit_dart
  levit_dart_core:
    path: $root/packages/core/levit_dart_core
  levit_scope:
    path: $root/packages/core/levit_scope
  levit_reactive:
    path: $root/packages/core/levit_reactive
''');
    await File('${temporary.path}/analysis_options.yaml').writeAsString('''
plugins:
  levit_lints:
    path: $root/packages/tools/levit_lints
    diagnostics:
      await_levit_lifecycle: true
      avoid_global_levit_in_widgets: true
      discarded_levit_future: true
''');
    Future<ProcessResult> run(List<String> args) => Process.run(
      Platform.resolvedExecutable,
      ['--suppress-analytics', ...args],
      workingDirectory: temporary.path,
    );
    final get = await run(['pub', 'get', '--offline']);
    if (get.exitCode != 0) throw StateError('${get.stdout}\n${get.stderr}');
    final source = File('${temporary.path}/main.dart');
    await source.writeAsString('''
import 'package:levit/levit.dart';
class Owner extends LevitController {
  @override
  Future<void> onBeforeClose() async { super.onBeforeClose(); }
}
void main() {
  Levit.reset();
  Owner().onClose();
  final source = 0.lx;
  LxWorker(source, (_) {}).close();
}
''');
    final invalid = await run(['analyze', '--fatal-infos', '--format=machine']);
    final diagnostics = '${invalid.stdout}\n${invalid.stderr}'.toLowerCase();
    if (invalid.exitCode == 0 ||
        !diagnostics.contains('await_levit_lifecycle') ||
        RegExp('discarded_levit_future').allMatches(diagnostics).length != 3 ||
        diagnostics.contains('error|')) {
      throw StateError(
        'Native plugin failed to report expected lints:\n$diagnostics',
      );
    }
    print(
      'Native plugin loaded: async super delegation plus facade, owner and worker cleanup diagnostics.',
    );
    await source.writeAsString('''
import 'package:levit/levit.dart';
class Owner extends LevitController {
  @override
  Future<void> onBeforeClose() async { await super.onBeforeClose(); }
}
Future<void> main() async { await Levit.reset(); }
''');
    final valid = await run(['analyze', '--fatal-infos']);
    if (valid.exitCode != 0) {
      throw StateError('${valid.stdout}\n${valid.stderr}');
    }
    print('Valid consumer passed fatal-info analysis.');
  } finally {
    await temporary.delete(recursive: true);
  }
}
