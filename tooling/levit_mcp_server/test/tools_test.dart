import 'dart:convert';
import 'dart:io';

import 'package:levit_mcp_server/levit_mcp_server.dart';
import 'package:test/test.dart';

void main() {
  group('LevitToolRegistry', () {
    late Directory workspace;
    late LevitToolRegistry registry;

    setUp(() async {
      workspace = await _createWorkspaceFixture();
      registry = LevitToolRegistry(workspaceDirectory: workspace);
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test('levit_reactive_simulate returns deterministic output', () async {
      final result =
          await registry.call('levit_reactive_simulate', <String, dynamic>{
        'initial': 2,
        'updates': <int>[3, -1],
      });

      expect(result.isError, isFalse);
      expect(result.structured, isNotNull);
      expect(result.structured!['finalCount'], 4);
      expect(result.structured!['finalDoubled'], 8);
    });

    test('levit_workspace_scan finds local packages', () async {
      final result =
          await registry.call('levit_workspace_scan', <String, dynamic>{});

      expect(result.isError, isFalse);
      expect(result.structured!['count'], 2);

      final packages = (result.structured!['packages'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(packages.any((pkg) => pkg['name'] == 'alpha_core'), isTrue);
      expect(packages.any((pkg) => pkg['name'] == 'alpha_kit'), isTrue);
    });

    test('levit_api_lookup returns symbol matches', () async {
      final result = await registry.call('levit_api_lookup', <String, dynamic>{
        'symbol': 'AlphaController',
      });

      expect(result.isError, isFalse);
      expect(result.structured!['count'], 1);
    });

    test('levit_docs_search returns markdown hits', () async {
      final result = await registry.call('levit_docs_search', <String, dynamic>{
        'query': 'reactive signals',
      });

      expect(result.isError, isFalse);
      expect(result.structured!['count'], 1);
    });

    test('levit_affected_packages maps changed paths', () async {
      final result =
          await registry.call('levit_affected_packages', <String, dynamic>{
        'changedPaths': <String>[
          'packages/core/alpha_core/lib/alpha_core.dart',
          'README.md',
        ],
      });

      expect(result.isError, isFalse);
      expect(result.structured!['count'], 1);
      expect(
          result.structured!['packages'], <String>['packages/core/alpha_core']);
    });

    test('levit_analyze_packages dry run plans command', () async {
      final result =
          await registry.call('levit_analyze_packages', <String, dynamic>{
        'packageNames': <String>['alpha_core'],
      });

      expect(result.isError, isFalse);
      expect(result.structured!['dryRun'], isTrue);
      final runs = (result.structured!['results'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(runs.single['status'], 'planned');
    });

    test('resource list and read are available', () async {
      final resources = registry.listResources();
      expect(
          resources.any((r) => r.uri == 'levit://workspace/packages'), isTrue);

      final read = await registry.readResource('levit://workspace/packages');
      final contents =
          (read['contents'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(contents.single['mimeType'], 'application/json');

      final jsonBody =
          jsonDecode(contents.single['text'] as String) as Map<String, dynamic>;
      expect(jsonBody['count'], 2);
    });
  });
}

Future<Directory> _createWorkspaceFixture() async {
  final root = await Directory.systemTemp.createTemp('levit_mcp_fixture_');

  await _writeFile('${root.path}/README.md', '# Workspace\n');

  await _writeFile(
    '${root.path}/packages/core/alpha_core/pubspec.yaml',
    'name: alpha_core\n',
  );
  await _writeFile(
    '${root.path}/packages/core/alpha_core/lib/alpha_core.dart',
    'class AlphaController {}\n',
  );
  await _writeFile(
    '${root.path}/packages/core/alpha_core/README.md',
    'alpha_core uses reactive signals.\n',
  );

  await _writeFile(
    '${root.path}/packages/kits/alpha_kit/pubspec.yaml',
    'name: alpha_kit\n',
  );
  await _writeFile(
    '${root.path}/packages/kits/alpha_kit/lib/alpha_kit.dart',
    'export "package:alpha_core/alpha_core.dart";\n',
  );
  await _writeFile(
    '${root.path}/packages/kits/alpha_kit/README.md',
    'kit readme\n',
  );

  return root;
}

Future<void> _writeFile(String path, String content) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
