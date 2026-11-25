import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'src/benchmark_support.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('before-root', mandatory: true)
    ..addOption('after-root', mandatory: true)
    ..addOption('output', mandatory: true)
    ..addOption('flutter', mandatory: true)
    ..addOption('mode', allowed: ['profile', 'release'], defaultsTo: 'release')
    ..addFlag('chain-only', negatable: false)
    ..addFlag('grid-only', negatable: false);
  final args = parseOptions(
    arguments,
    parser,
    'Compare native dashboard workloads across two checkouts.',
  );
  if (args == null) return;
  requireCondition(
    !(args.flag('chain-only') && args.flag('grid-only')),
    'Choose at most one of --chain-only and --grid-only',
  );
  final output = p.absolute(args.option('output')!);
  Directory(output).createSync(recursive: true);
  final roots = {
    'before': Directory(args.option('before-root')!).resolveSymbolicLinksSync(),
    'after': Directory(args.option('after-root')!).resolveSymbolicLinksSync(),
  };
  final mode = args.option('mode')!;
  final inputs = <String, JsonMap>{};
  for (final entry in roots.entries) {
    final files = sourceManifest(entry.value);
    inputs[entry.key] = {
      'root': entry.value,
      'digest': manifestDigest(files),
      'files': files,
    };
  }
  final beforeFiles = inputs['before']!['files'] as Map<String, String>;
  final afterFiles = inputs['after']!['files'] as Map<String, String>;
  for (final path in {...beforeFiles.keys, ...afterFiles.keys}) {
    if (path.startsWith('benchmarks/')) {
      requireCondition(
        beforeFiles[path] == afterFiles[path],
        'Benchmark source or lock changed: $path',
      );
    }
  }
  writeJson(p.join(output, 'inputs.json'), inputs);
  const order = ['before', 'after', 'after', 'before'];
  final runs = <JsonMap>[];
  final metadata = {
    'mode': mode,
    'order': order,
    'gridOnly': args.flag('grid-only'),
    'chainOnly': args.flag('chain-only'),
    'inputs': inputs,
    'runs': runs,
  };
  var target = 'lib/compare_app_workloads.dart';
  var expectedCount = 60;
  if (args.flag('chain-only')) {
    target = 'lib/compare_chain_workload.dart';
    expectedCount = 2;
  }
  if (args.flag('grid-only')) {
    target = 'lib/compare_grid_workload.dart';
    expectedCount = 5;
  }
  for (final entry in roots.entries) {
    print('Building ${entry.key} $mode');
    await runLogged(
      [
        args.option('flutter')!,
        'build',
        'macos',
        '--$mode',
        '--target=$target',
        '--dart-define=BENCHMARK_REVISION=${inputs[entry.key]!['digest']}',
      ],
      p.join(output, '${entry.key}-build.log'),
      workingDirectory: p.join(entry.value, 'benchmarks'),
    );
    final binary = appBinary(entry.value, mode);
    inputs[entry.key]!['binarySha256'] = fileDigest(binary);
    inputs[entry.key]!['dartAotSha256'] = fileDigest(appAot(binary));
  }
  List<dynamic>? geometry;
  for (var index = 0; index < order.length; index++) {
    final label = order[index];
    final name = '${(index + 1).toString().padLeft(2, '0')}-$label';
    print('Running $name $mode');
    final timer = Stopwatch()..start();
    final result = await runLogged(
      [appBinary(roots[label]!, mode)],
      p.join(output, '$name.log'),
      workingDirectory: Directory.current.path,
      environment: {
        ...Platform.environment,
        'LEVIT_PERFORMANCE_RUN': '1',
        'LEVIT_DIAGNOSTICS': 'off',
      },
    );
    final report = extractReport(
      '${result.stdout}${result.stderr}',
      'APP_COMPARISON_JSON:',
    );
    final environment = report['environment'] as JsonMap;
    final currentGeometry = [
      environment['display'],
      environment['refreshRate'],
    ];
    geometry ??= currentGeometry;
    requireCondition(
      sameJson(geometry, currentGeometry),
      'Viewport or refresh rate changed',
    );
    requireCondition(
      environment['sourceRevision'] == inputs[label]!['digest'],
      'Binary source identity mismatch',
    );
    requireCondition(
      report['methodologyVersion'] == 2 &&
          (report['results'] as List).length == expectedCount,
      'Unexpected methodology or result count',
    );
    requireCondition(
      environment['iterations'] == 50 && environment['warmupIterations'] == 5,
      'Workload sample count changed',
    );
    writeJson(p.join(output, '$name.json'), report);
    runs.add({
      'name': name,
      'seconds': timer.elapsedMicroseconds / 1e6,
      'geometry': currentGeometry,
    });
    writeJson(p.join(output, 'comparison.json'), metadata);
    print('Validated $name: $expectedCount cases');
  }
  print('Comparison complete');
}
