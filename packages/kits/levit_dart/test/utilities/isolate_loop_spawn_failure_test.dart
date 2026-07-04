import 'dart:async';
import 'dart:mirrors';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

void main() {
  test('startIsolateLoop reports LxError when isolate spawn throws', () async {
    final engine = LevitLoopEngine();

    final lib = reflectClass(LevitLoopEngine).owner as LibraryMirror;
    final spawnerSymbol = MirrorSystem.getSymbol('_spawnIsolate', lib);
    final originalSpawner = lib.getField(spawnerSymbol).reflectee;

    addTearDown(() {
      lib.setField(spawnerSymbol, originalSpawner);
    });

    lib.setField(spawnerSymbol, (entryPoint, message, {String? debugName}) {
      throw StateError('spawn-fail');
    });

    engine.startIsolateLoop('bad_loop', _noopBody);

    LxStatus<dynamic>? status;
    final deadline = DateTime.now().add(const Duration(seconds: 1));
    while (DateTime.now().isBefore(deadline)) {
      status = engine.getServiceStatus('bad_loop')?.value;
      if (status is LxError) break;
      await Future.delayed(const Duration(milliseconds: 10));
    }

    expect(status, isA<LxError>());
    engine.dispose();
  });
}

FutureOr<void> _noopBody() {}
