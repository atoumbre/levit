import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:levit_devtools/levit_devtools.dart';
import 'package:test/test.dart';

void main() {
  test(
    'bundled assets are complete and CLI serves them without Flutter installed',
    () async {
      final assets = await LevitInspectorServer.bundledAssets();
      expect(await File('${assets.path}/index.html').exists(), isTrue);
      expect(await File('${assets.path}/main.dart.js').exists(), isTrue);
      final fonts =
          jsonDecode(
                await File(
                  '${assets.path}/assets/FontManifest.json',
                ).readAsString(),
              )
              as List;
      expect(fonts.any((font) => font['family'] == 'Roboto'), isTrue);
      final bootstrap = await File(
        '${assets.path}/flutter_bootstrap.js',
      ).readAsString();
      expect(
        bootstrap,
        contains('fontFallbackBaseUrl: "assets/fonts/fallback/"'),
      );
      expect(
        await File('${assets.path}/canvaskit/canvaskit.wasm').exists(),
        isTrue,
      );
      final process = await Process.start(Platform.resolvedExecutable, [
        '--suppress-analytics',
        'run',
        'bin/levit_devtools.dart',
        '--port',
        '0',
      ]);
      final errors = <String>[];
      final stderr = process.stderr.transform(utf8.decoder).listen(errors.add);
      final lines = StreamIterator(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      );
      try {
        expect(
          await lines.moveNext().timeout(const Duration(seconds: 20)),
          isTrue,
          reason: errors.join(),
        );
        final url = Uri.parse(lines.current.split('Levit inspector: ').last);
        final client = HttpClient();
        try {
          final response = await (await client.getUrl(url)).close();
          expect(
            await utf8.decoder.bind(response).join(),
            contains('Levit Inspector'),
          );
          final js = await (await client.getUrl(
            url.resolve('/main.dart.js'),
          )).close();
          expect(js.statusCode, 200);
          expect(js.headers.contentType?.mimeType, 'application/javascript');
          await js.drain<void>();
        } finally {
          client.close(force: true);
        }
      } finally {
        process.kill(ProcessSignal.sigint);
        expect(
          await process.exitCode.timeout(const Duration(seconds: 10)),
          0,
          reason: errors.join(),
        );
        await stderr.cancel();
        await lines.cancel();
      }
    },
  );
}
