import 'dart:convert';
import 'dart:io';

/// Builds the private UI and stages only release assets in the Dart CLI package.
Future<void> main() async {
  final root = Directory.current;
  final ui = Directory('${root.path}/packages/tools/levit_devtools_ui');
  final result = await Process.start(
    'flutter',
    [
      '--suppress-analytics',
      'build',
      'web',
      '--release',
      '--no-web-resources-cdn',
    ],
    workingDirectory: ui.path,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await result.exitCode;
  if (code != 0) {
    exitCode = code;
    return;
  }
  final assets = Directory(
    '${root.path}/packages/tools/levit_devtools/lib/assets',
  );
  if (await assets.exists()) await assets.delete(recursive: true);
  await assets.create(recursive: true);
  final build = Directory('${ui.path}/build/web');
  for (final file in build.listSync(recursive: true).whereType<File>()) {
    final relative = file.path.substring(build.path.length + 1);
    // Flutter's dev-server stamp changes on every build; it is not a web asset.
    if (relative == '.last_build_id') {
      continue;
    }
    final target = File('${assets.path}/$relative');
    await target.parent.create(recursive: true);
    await file.copy(target.path);
  }
  await File('${assets.path}/levit-build.json').writeAsString(
    jsonEncode({
      'uiPackage': 'levit_devtools_ui',
      'version': jsonDecode(
        await File('${build.path}/version.json').readAsString(),
      )['version'],
      'mode': 'release',
    }),
  );
  stdout.writeln('Bundled inspector assets in ${assets.path}');
}
