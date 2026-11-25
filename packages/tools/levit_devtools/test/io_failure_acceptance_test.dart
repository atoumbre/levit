import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:levit_devtools/levit_devtools.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

class UnreadableFile implements File {
  UnreadableFile(this.path, this.beforeHeaders);
  final bool beforeHeaders;
  @override
  final String path;
  @override
  Future<bool> exists() async {
    if (beforeHeaders) throw const FileSystemException('stat failed');
    return true;
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      Stream.error(const FileSystemException('read failed'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FailingCloseSocket extends Stream<Socket> implements ServerSocket {
  FailingCloseSocket(this.socket, this.failure);
  final ServerSocket socket;
  final Object failure;
  bool closed = false;
  @override
  int get port => socket.port;
  @override
  InternetAddress get address => socket.address;
  @override
  Future<ServerSocket> close() async {
    if (closed) return socket;
    closed = true;
    await socket.close();
    throw failure;
  }

  @override
  StreamSubscription<Socket> listen(
    void Function(Socket)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => socket.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

void main() {
  test('embedded asset resolution reports missing package mappings', () async {
    await expectLater(
      LevitInspectorServer.bundledAssets(
        resolve: (uri) async {
          expect(uri.toString(), 'package:levit_devtools/levit_devtools.dart');
          return null;
        },
      ),
      throwsStateError,
    );
  });
  for (final beforeHeaders in [true, false]) {
    test(
      'HTTP asset failure drains response and is reported at shutdown, beforeHeaders=$beforeHeaders',
      () async {
        final assets = await Directory.systemTemp.createTemp(
          'levit-io-failure-',
        );
        await File('${assets.path}/index.html').writeAsString('inspector');
        final server = LevitInspectorServer(assets: assets);
        final parent = Zone.current;
        await IOOverrides.runZoned(
          () => server.start(port: 0),
          createFile: (path) => path.endsWith('/broken.js')
              ? UnreadableFile(path, beforeHeaders)
              : parent.run(() => File(path)),
        );
        final client = HttpClient();
        try {
          final request = await client.getUrl(server.uri.resolve('/broken.js'));
          if (beforeHeaders) {
            final response = await request.close();
            expect(response.statusCode, 500);
            await response.drain<void>();
          } else {
            await expectLater(
              request.close().then((response) => response.drain<void>()),
              throwsA(isA<HttpException>()),
            );
          }
          await expectLater(
            server.close(),
            throwsA(
              isA<LevitMonitorException>().having(
                (e) => e.failures.first.error,
                'original failure',
                isA<FileSystemException>(),
              ),
            ),
          );
        } finally {
          client.close(force: true);
          try {
            await server.close();
          } catch (_) {}
          await assets.delete(recursive: true);
        }
      },
    );
  }

  test(
    'listener close failure is reported by the shared awaited shutdown',
    () async {
      final assets = await Directory.systemTemp.createTemp(
        'levit-close-failure-',
      );
      await File('${assets.path}/index.html').writeAsString('inspector');
      final failure = StateError('listener close');
      final parent = Zone.current;
      final server = LevitInspectorServer(assets: assets);
      await IOOverrides.runZoned(
        () => server.start(port: 0),
        serverSocketBind:
            (
              address,
              port, {
              int backlog = 0,
              bool v6Only = false,
              bool shared = false,
            }) async => FailingCloseSocket(
              await parent.run(
                () => ServerSocket.bind(
                  address,
                  port,
                  backlog: backlog,
                  v6Only: v6Only,
                  shared: shared,
                ),
              ),
              failure,
            ),
      );
      final closing = server.close();
      expect(identical(closing, server.close()), isTrue);
      await expectLater(
        closing,
        throwsA(
          isA<LevitMonitorException>().having(
            (e) => e.failures.single.error,
            'release failure',
            same(failure),
          ),
        ),
      );
      await assets.delete(recursive: true);
    },
  );

  test(
    'asset lookup reports an unresolvable package when loaded by file URI',
    () async {
      final configUri = (await Isolate.packageConfig)!;
      final config =
          jsonDecode(await File.fromUri(configUri).readAsString())
              as Map<String, dynamic>;
      final packages = (config['packages'] as List)
          .cast<Map<String, dynamic>>();
      packages.removeWhere((entry) => entry['name'] == 'levit_devtools');
      for (final entry in packages) {
        entry['rootUri'] = configUri
            .resolve(entry['rootUri'] as String)
            .toString();
      }
      config['packages'] = packages;
      final directory = await Directory.systemTemp.createTemp(
        'levit-package-config-',
      );
      final file = await File(
        '${directory.path}/package_config.json',
      ).writeAsString(jsonEncode(config));
      final result = ReceivePort();
      try {
        await Isolate.spawnUri(
          File('test/fixtures/unresolved_assets.dart').absolute.uri,
          [],
          result.sendPort,
          packageConfig: file.uri,
          onError: result.sendPort,
        );
        expect(
          await result.first.timeout(const Duration(seconds: 20)),
          contains('Cannot locate bundled inspector assets'),
        );
      } finally {
        result.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
