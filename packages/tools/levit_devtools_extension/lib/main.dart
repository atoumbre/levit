import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'src/client/devtools_client.dart';
import 'src/client/vm_service_client.dart';
import 'src/views/levit_devtools_screen.dart';

void main() {
  Levit.enableAutoLinking();
  runApp(const DevToolsExtension(child: LevitDevToolsApp()));
}

/// Root widget hosted inside Flutter DevTools via [DevToolsExtension].
class LevitDevToolsApp extends StatelessWidget {
  /// Optional client override for tests or standalone previews.
  final LevitDevToolsClient? client;

  const LevitDevToolsApp({super.key, this.client});

  @override
  Widget build(BuildContext context) {
    return LevitDevToolsScreen(
      client: client ?? VmServiceLevitClient(),
      ownsClient: client == null,
    );
  }
}
