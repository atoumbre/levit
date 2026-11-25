import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:test/test.dart';

void main() {
  test('core API enforces readable views and rejects removed APIs', () async {
    final directory = await Directory.systemTemp.createTemp(
      'levit-api-contract-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final configUri = (await Isolate.packageConfig)!;
    final config =
        jsonDecode(await File.fromUri(configUri).readAsString()) as Map;
    for (final entry in config['packages'] as List) {
      entry['rootUri'] = configUri
          .resolve(entry['rootUri'] as String)
          .toString();
    }
    await Directory('${directory.path}/.dart_tool').create();
    await File(
      '${directory.path}/.dart_tool/package_config.json',
    ).writeAsString(jsonEncode(config));
    await File(
      '${directory.path}/pubspec.yaml',
    ).writeAsString('name: levit_api_contract\nenvironment:\n  sdk: ^3.12.0\n');
    await File('${directory.path}/valid.dart').writeAsString('''
import 'package:levit_dart_core/levit_dart_core.dart';
void observe(LxReadable<int> value, LxState<int> state) {
  final int current = value.value;
  final LxReadable<int> borrowed = state.asReadable;
  borrowed.addListener(() { print(current); });
}
Future<void> setup(LevitScope scope) async {
  final store = LevitStore((ref) => ref.own(0.lx));
  final value = store.findIn(scope);
  value.value++;
  await scope.runInitialization(() async {});
}
''');
    final invalidStatements = [
      'readable.value = 1;',
      'readable.close();',
      'readable.refresh();',
      "readable.name = 'changed';",
      "readable.ownerId = 'changed';",
      'readable.isSensitive = true;',
      'state.asReadable.close();',
      'state.asReadable.value = 1;',
      'Object().toBuilder;',
      '(() => Object()).levitPut();',
      '(() => Object()).levitLazyPut();',
      '(() async => Object()).levitLazyPutAsync();',
      'owner.autoDispose(0.lx);',
      'owner.initialized;',
      'computed.computedValue;',
      'owner.runGuardedAsync(() async => 1, cancelOnClose: true);',
      'LevitReactiveHistoryMiddleware();',
      "ref.findStore('dynamic-key');",
    ];
    const header = '''import 'package:levit_dart_core/levit_dart_core.dart';
void removed(LxReadable<int> readable, LxState<int> state,
    LevitController owner, LxAsyncComputed<int> computed, LevitRef ref) {
''';
    await File(
      '${directory.path}/invalid.dart',
    ).writeAsString('$header${invalidStatements.join('\n')}\n}\n');
    final analysis = await Process.run(Platform.resolvedExecutable, [
      '--suppress-analytics',
      'analyze',
      '--format=machine',
      directory.path,
    ]);
    final diagnostics = '${analysis.stdout}\n${analysis.stderr}'
        .split('\n')
        .where((line) => line.startsWith('ERROR|'))
        .map((line) => line.split('|'))
        .toList();
    expect(analysis.exitCode, isNonZero);
    expect(
      diagnostics.where((parts) => parts[3].endsWith('/valid.dart')),
      isEmpty,
      reason: '${analysis.stdout}\n${analysis.stderr}',
    );
    final invalidLines = diagnostics
        .where((parts) => parts[3].endsWith('/invalid.dart'))
        .map((parts) => int.parse(parts[4]))
        .toSet();
    final firstLine = '\n'.allMatches(header).length + 1;
    expect(invalidLines, {
      for (var i = 0; i < invalidStatements.length; i++) firstLine + i,
    }, reason: '${analysis.stdout}\n${analysis.stderr}');
  });
}
