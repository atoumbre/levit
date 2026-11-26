import 'package:levit_devtools/levit_devtools.dart';

Future<void> main() async {
  await LevitDevTools.attach(historyCapacity: 500);
  // Run your Dart or Flutter application, then open Flutter DevTools.
  await LevitDevTools.detach();
}
