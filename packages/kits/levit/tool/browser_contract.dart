import 'package:levit/levit.dart';

/// Browser compilation contract for the Dart kit's public runtime entrypoint.
Future<void> main() async {
  final scope = Levit.createScope('browser');
  final queries = LevitAsyncMap<String, int>(
    (key, context) async => key.length,
  );
  try {
    await queries.fetch('hello');
  } finally {
    await queries.dispose();
    await scope.dispose();
  }
}
