import 'dart:isolate';
// Intentionally bypass package resolution to exercise a file-loaded launcher.
// ignore: avoid_relative_lib_imports
import '../../lib/levit_devtools.dart';

Future<void> main(List<String> arguments, SendPort result) async {
  try {
    await LevitInspectorServer.bundledAssets();
    result.send('unexpected success');
  } catch (error) {
    result.send(error.toString());
  }
}
