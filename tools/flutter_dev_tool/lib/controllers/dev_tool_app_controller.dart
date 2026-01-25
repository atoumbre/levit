import 'package:dev_tool_server/dev_tool_server.dart';
import 'package:flutter/foundation.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';
import 'package:levit_dart_core/levit_dart_core.dart';

class DevToolAppController extends LevitController {
  late final DevToolController server;

  // Track selected session reactively
  final selectedSession = LxVar<AppSession?>(null);

  // Track filter selection (ScopeID:ControllerKey)
  final filterControllerKey = LxVar<String?>(null);

  @override
  void onInit() {
    super.onInit();
    // Initialize the server controller
    server = DevToolController();

    // Start the server
    _startServer();
  }

  Future<void> _startServer() async {
    try {
      await server.start();
    } catch (e) {
      debugPrint('Failed to start server: $e');
    }
  }

  @override
  void onClose() {
    server.stop();
    super.onClose();
  }
}
