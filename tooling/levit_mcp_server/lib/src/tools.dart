import 'dart:convert';
import 'dart:io';

import 'package:levit_reactive/levit_reactive.dart';

typedef ToolHandler = Future<ToolCallResult> Function(
    Map<String, dynamic> args);

class McpTool {
  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final ToolHandler handler;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'description': description,
      'inputSchema': inputSchema,
    };
  }
}

class McpResource {
  const McpResource({
    required this.uri,
    required this.name,
    required this.mimeType,
    required this.description,
  });

  final String uri;
  final String name;
  final String mimeType;
  final String description;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uri': uri,
      'name': name,
      'mimeType': mimeType,
      'description': description,
    };
  }
}

class ToolCallResult {
  const ToolCallResult({
    required this.message,
    this.structured,
    this.isError = false,
  });

  final String message;
  final Map<String, dynamic>? structured;
  final bool isError;

  Map<String, dynamic> toMcpResult() {
    final result = <String, dynamic>{
      'content': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'text', 'text': message},
      ],
      'isError': isError,
    };

    if (structured != null) {
      result['structuredContent'] = structured;
    }

    return result;
  }
}

class LevitToolRegistry {
  LevitToolRegistry({Directory? workspaceDirectory})
      : _workspaceDirectory = workspaceDirectory ?? Directory.current {
    _tools = <String, McpTool>{
      _simulateReactiveTool.name: _simulateReactiveTool,
      _scanWorkspaceTool.name: _scanWorkspaceTool,
      _apiLookupTool.name: _apiLookupTool,
      _docsSearchTool.name: _docsSearchTool,
      _affectedPackagesTool.name: _affectedPackagesTool,
      _analyzePackagesTool.name: _analyzePackagesTool,
    };
  }

  final Directory _workspaceDirectory;
  late final Map<String, McpTool> _tools;

  List<McpTool> listTools() {
    final tools = _tools.values.toList(growable: false);
    tools.sort((a, b) => a.name.compareTo(b.name));
    return tools;
  }

  List<McpResource> listResources() {
    return const <McpResource>[
      McpResource(
        uri: 'levit://workspace/packages',
        name: 'Workspace Packages',
        mimeType: 'application/json',
        description: 'Discovered Levit workspace packages and paths.',
      ),
      McpResource(
        uri: 'levit://workspace/affected_packages',
        name: 'Affected Packages',
        mimeType: 'application/json',
        description: 'Packages inferred from current changed files.',
      ),
    ];
  }

  Future<Map<String, dynamic>> readResource(String uri) async {
    switch (uri) {
      case 'levit://workspace/packages':
        final result = await _scanWorkspaceTool.handler(<String, dynamic>{});
        return <String, dynamic>{
          'contents': <Map<String, dynamic>>[
            <String, dynamic>{
              'uri': uri,
              'mimeType': 'application/json',
              'text': result.message,
            },
          ],
        };
      case 'levit://workspace/affected_packages':
        final result = await _affectedPackagesTool.handler(<String, dynamic>{});
        return <String, dynamic>{
          'contents': <Map<String, dynamic>>[
            <String, dynamic>{
              'uri': uri,
              'mimeType': 'application/json',
              'text': result.message,
            },
          ],
        };
      default:
        throw ArgumentError('Unknown resource URI: $uri');
    }
  }

  Future<ToolCallResult> call(String name, Map<String, dynamic> args) async {
    final tool = _tools[name];
    if (tool == null) {
      return ToolCallResult(
        message: 'Unknown tool: $name',
        isError: true,
      );
    }

    try {
      return await tool.handler(args);
    } catch (error, stackTrace) {
      final payload = jsonEncode(<String, dynamic>{
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      });
      return ToolCallResult(
        message: 'Tool failed: $payload',
        isError: true,
      );
    }
  }

  McpTool get _simulateReactiveTool => McpTool(
        name: 'levit_reactive_simulate',
        description:
            'Run a small deterministic reactive simulation using levit_reactive.',
        inputSchema: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'initial': <String, dynamic>{
              'type': 'integer',
              'description': 'Initial counter value.',
              'default': 0,
            },
            'updates': <String, dynamic>{
              'type': 'array',
              'description': 'Delta updates applied sequentially.',
              'items': <String, dynamic>{'type': 'integer'},
              'default': <int>[1, 1, 1],
            },
          },
          'additionalProperties': false,
        },
        handler: (args) async {
          final initial = _readInt(args['initial'], fallback: 0);
          final updates =
              _readIntList(args['updates'], fallback: <int>[1, 1, 1]);

          final count = initial.lx;
          final doubled = LxComputed<int>(() => count() * 2);
          final history = <Map<String, int>>[];

          try {
            for (final delta in updates) {
              count(count() + delta);
              history.add(<String, int>{
                'count': count(),
                'doubled': doubled(),
              });
            }

            final result = <String, dynamic>{
              'initial': initial,
              'updates': updates,
              'finalCount': count(),
              'finalDoubled': doubled(),
              'history': history,
            };

            return ToolCallResult(
                message: jsonEncode(result), structured: result);
          } finally {
            doubled.close();
            count.close();
          }
        },
      );

  McpTool get _scanWorkspaceTool => McpTool(
        name: 'levit_workspace_scan',
        description:
            'Scan workspace packages under packages/*/* and return Levit package metadata.',
        inputSchema: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'rootPath': <String, dynamic>{
              'type': 'string',
              'description':
                  'Optional workspace root path. Defaults to server cwd.',
            },
          },
          'additionalProperties': false,
        },
        handler: (args) async {
          final root = _resolveRoot(args['rootPath'] as String?);
          final packages = _discoverPackages(root);

          final result = <String, dynamic>{
            'rootPath': root.path,
            'count': packages.length,
            'packages':
                packages.map((pkg) => pkg.toJson()).toList(growable: false),
          };

          return ToolCallResult(
              message: jsonEncode(result), structured: result);
        },
      );

  McpTool get _apiLookupTool => McpTool(
        name: 'levit_api_lookup',
        description:
            'Lookup symbol references in Dart source files across Levit packages.',
        inputSchema: <String, dynamic>{
          'type': 'object',
          'required': <String>['symbol'],
          'properties': <String, dynamic>{
            'symbol': <String, dynamic>{
              'type': 'string',
              'description': 'Dart symbol to search for, e.g. LxComputed.',
            },
            'maxResults': <String, dynamic>{
              'type': 'integer',
              'description': 'Maximum number of matches to return.',
              'default': 50,
            },
          },
          'additionalProperties': false,
        },
        handler: (args) async {
          final symbol = (args['symbol'] as String?)?.trim() ?? '';
          if (symbol.isEmpty) {
            return const ToolCallResult(
              message: 'Missing required argument: symbol',
              isError: true,
            );
          }

          final maxResults =
              _readInt(args['maxResults'], fallback: 50).clamp(1, 200);
          final packages = _discoverPackages(_workspaceDirectory);
          final matches = <Map<String, dynamic>>[];
          final pattern = RegExp(r'\b' + RegExp.escape(symbol) + r'\b');

          for (final pkg in packages) {
            final libDir = Directory('${pkg.path}/lib');
            if (!libDir.existsSync()) {
              continue;
            }

            final files = libDir
                .listSync(recursive: true, followLinks: false)
                .whereType<File>()
                .where((file) => file.path.endsWith('.dart'));

            for (final file in files) {
              final lines = file.readAsLinesSync();
              for (var i = 0; i < lines.length; i++) {
                if (!pattern.hasMatch(lines[i])) {
                  continue;
                }
                matches.add(<String, dynamic>{
                  'package': pkg.name,
                  'path': _toRelativePath(file.path),
                  'line': i + 1,
                  'snippet': lines[i].trim(),
                });
                if (matches.length >= maxResults) {
                  break;
                }
              }
              if (matches.length >= maxResults) {
                break;
              }
            }
            if (matches.length >= maxResults) {
              break;
            }
          }

          final result = <String, dynamic>{
            'symbol': symbol,
            'count': matches.length,
            'matches': matches,
          };
          return ToolCallResult(
              message: jsonEncode(result), structured: result);
        },
      );

  McpTool get _docsSearchTool => McpTool(
        name: 'levit_docs_search',
        description:
            'Search Levit markdown docs (README/CHANGELOG and docs files) by text query.',
        inputSchema: <String, dynamic>{
          'type': 'object',
          'required': <String>['query'],
          'properties': <String, dynamic>{
            'query': <String, dynamic>{
              'type': 'string',
              'description': 'Case-insensitive substring query.',
            },
            'maxResults': <String, dynamic>{
              'type': 'integer',
              'default': 20,
            },
          },
          'additionalProperties': false,
        },
        handler: (args) async {
          final query = (args['query'] as String?)?.trim() ?? '';
          if (query.isEmpty) {
            return const ToolCallResult(
              message: 'Missing required argument: query',
              isError: true,
            );
          }
          final maxResults =
              _readInt(args['maxResults'], fallback: 20).clamp(1, 100);
          final queryLower = query.toLowerCase();

          final candidates = <File>[];
          final rootReadme = File('${_workspaceDirectory.path}/README.md');
          if (rootReadme.existsSync()) {
            candidates.add(rootReadme);
          }

          for (final pkg in _discoverPackages(_workspaceDirectory)) {
            final readme = File('${pkg.path}/README.md');
            if (readme.existsSync()) {
              candidates.add(readme);
            }
            final changelog = File('${pkg.path}/CHANGELOG.md');
            if (changelog.existsSync()) {
              candidates.add(changelog);
            }
          }

          final matches = <Map<String, dynamic>>[];
          for (final file in candidates) {
            final lines = file.readAsLinesSync();
            for (var i = 0; i < lines.length; i++) {
              if (!lines[i].toLowerCase().contains(queryLower)) {
                continue;
              }
              matches.add(<String, dynamic>{
                'path': _toRelativePath(file.path),
                'line': i + 1,
                'snippet': lines[i].trim(),
              });
              if (matches.length >= maxResults) {
                break;
              }
            }
            if (matches.length >= maxResults) {
              break;
            }
          }

          final result = <String, dynamic>{
            'query': query,
            'count': matches.length,
            'matches': matches,
          };
          return ToolCallResult(
              message: jsonEncode(result), structured: result);
        },
      );

  McpTool get _affectedPackagesTool => McpTool(
        name: 'levit_affected_packages',
        description:
            'Infer affected packages from changed file paths or current git status.',
        inputSchema: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'changedPaths': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{'type': 'string'},
              'description':
                  'Optional list of changed paths. If omitted, git status is used.',
            },
          },
          'additionalProperties': false,
        },
        handler: (args) async {
          final explicitPaths = _readStringList(args['changedPaths']);
          final changedPaths = explicitPaths ?? await _gitChangedPaths();
          final packages = _packagesFromPaths(changedPaths);

          final result = <String, dynamic>{
            'changedPathCount': changedPaths.length,
            'changedPaths': changedPaths,
            'count': packages.length,
            'packages': packages,
          };

          return ToolCallResult(
              message: jsonEncode(result), structured: result);
        },
      );

  McpTool get _analyzePackagesTool => McpTool(
        name: 'levit_analyze_packages',
        description:
            'Run dart analyze for selected packages. Defaults to dryRun=true.',
        inputSchema: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'packageNames': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{'type': 'string'},
              'description':
                  'Package names to analyze. Defaults to affected packages.',
            },
            'dryRun': <String, dynamic>{
              'type': 'boolean',
              'default': true,
            },
          },
          'additionalProperties': false,
        },
        handler: (args) async {
          final dryRun = args['dryRun'] is bool ? args['dryRun'] as bool : true;
          final requested = _readStringList(args['packageNames']) ?? <String>[];
          final packages = _discoverPackages(_workspaceDirectory);
          final byName = <String, _WorkspacePackage>{
            for (final pkg in packages) pkg.name: pkg,
          };

          final targetNames = requested.isNotEmpty
              ? requested
              : await _inferAffectedPackageNames(byName.keys.toSet());

          if (targetNames.isEmpty) {
            final emptyResult = <String, dynamic>{
              'dryRun': dryRun,
              'count': 0,
              'results': <Map<String, dynamic>>[],
            };
            return ToolCallResult(
              message: jsonEncode(emptyResult),
              structured: emptyResult,
            );
          }

          final runs = <Map<String, dynamic>>[];
          for (final name in targetNames) {
            final pkg = byName[name];
            if (pkg == null) {
              runs.add(<String, dynamic>{
                'package': name,
                'status': 'missing',
                'exitCode': -1,
                'stdout': '',
                'stderr': 'Package not found in workspace scan.',
              });
              continue;
            }

            if (dryRun) {
              runs.add(<String, dynamic>{
                'package': name,
                'status': 'planned',
                'command': 'dart analyze',
                'path': _toRelativePath(pkg.path),
              });
              continue;
            }

            final process = await Process.run(
              'dart',
              <String>['analyze'],
              workingDirectory: pkg.path,
            );
            runs.add(<String, dynamic>{
              'package': name,
              'status': process.exitCode == 0 ? 'ok' : 'failed',
              'exitCode': process.exitCode,
              'stdout': (process.stdout as String).trim(),
              'stderr': (process.stderr as String).trim(),
            });
          }

          final failed = runs.where((run) => run['status'] == 'failed').length;
          final result = <String, dynamic>{
            'dryRun': dryRun,
            'count': runs.length,
            'failed': failed,
            'results': runs,
          };
          return ToolCallResult(
              message: jsonEncode(result), structured: result);
        },
      );

  Directory _resolveRoot(String? configuredRoot) {
    final trimmed = configuredRoot?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return _workspaceDirectory;
    }
    return Directory(trimmed);
  }

  List<_WorkspacePackage> _discoverPackages(Directory root) {
    final packagesRoot = Directory('${root.path}/packages');
    if (!packagesRoot.existsSync()) {
      return const <_WorkspacePackage>[];
    }

    final results = <_WorkspacePackage>[];
    for (final group in packagesRoot.listSync(followLinks: false)) {
      if (group is! Directory) {
        continue;
      }
      for (final packageDir in group.listSync(followLinks: false)) {
        if (packageDir is! Directory) {
          continue;
        }

        final pubspec = File('${packageDir.path}/pubspec.yaml');
        if (!pubspec.existsSync()) {
          continue;
        }

        final name = _readPackageName(pubspec.readAsStringSync());
        if (name == null) {
          continue;
        }

        results.add(_WorkspacePackage(
          name: name,
          path: packageDir.path,
          group: _basename(group.path),
        ));
      }
    }

    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }

  String? _readPackageName(String pubspecContent) {
    final match = RegExp(r'^name:\s*([^\s]+)', multiLine: true)
        .firstMatch(pubspecContent);
    return match?.group(1);
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    if (index < 0) {
      return normalized;
    }
    return normalized.substring(index + 1);
  }

  String _toRelativePath(String path) {
    final root = _workspaceDirectory.path.replaceAll('\\', '/');
    final normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('$root/')) {
      return normalized.substring(root.length + 1);
    }
    return normalized;
  }

  List<String>? _readStringList(Object? value) {
    if (value is! List<Object?>) {
      return null;
    }
    return value
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> _gitChangedPaths() async {
    final result = await Process.run(
      'git',
      <String>['status', '--porcelain'],
      workingDirectory: _workspaceDirectory.path,
    );
    if (result.exitCode != 0) {
      return const <String>[];
    }

    final lines = (result.stdout as String)
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final paths = <String>[];
    for (final line in lines) {
      if (line.length < 4) {
        continue;
      }
      final pathPart = line.substring(3).trim();
      if (pathPart.isEmpty) {
        continue;
      }
      final renamed = pathPart.split(' -> ');
      paths.add(renamed.last.trim());
    }

    return paths;
  }

  List<String> _packagesFromPaths(List<String> changedPaths) {
    final packageRoots = <String>{};

    for (final rawPath in changedPaths) {
      final path = rawPath.replaceAll('\\', '/');
      final parts = path.split('/');
      if (parts.length < 3) {
        continue;
      }
      if (parts[0] != 'packages') {
        continue;
      }
      packageRoots.add('packages/${parts[1]}/${parts[2]}');
    }

    final sorted = packageRoots.toList(growable: false)..sort();
    return sorted;
  }

  Future<List<String>> _inferAffectedPackageNames(
      Set<String> validNames) async {
    final changedPaths = await _gitChangedPaths();
    final affectedPaths = _packagesFromPaths(changedPaths).toSet();
    final names = <String>[];

    for (final pkg in _discoverPackages(_workspaceDirectory)) {
      final relative = _toRelativePath(pkg.path);
      if (affectedPaths.contains(relative) && validNames.contains(pkg.name)) {
        names.add(pkg.name);
      }
    }

    return names;
  }
}

class _WorkspacePackage {
  const _WorkspacePackage({
    required this.name,
    required this.path,
    required this.group,
  });

  final String name;
  final String path;
  final String group;

  Map<String, String> toJson() {
    return <String, String>{
      'name': name,
      'path': path,
      'group': group,
    };
  }
}

int _readInt(Object? raw, {required int fallback}) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  return fallback;
}

List<int> _readIntList(Object? raw, {required List<int> fallback}) {
  if (raw is! List<Object?>) {
    return fallback;
  }
  return raw
      .whereType<num>()
      .map((value) => value.toInt())
      .toList(growable: false);
}
