import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';
import 'controllers/dev_tool_app_controller.dart';
import 'ui/main_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized before async calls
  WidgetsFlutterBinding.ensureInitialized();

  // No need for explicit server start here, controller handles it
  Levit.put(() => DevToolAppController());

  runApp(const DevToolApp());
}

class DevToolApp extends StatelessWidget {
  const DevToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Levit DevTool',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
