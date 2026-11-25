import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'controllers/benchmark_controller.dart';
import 'main.dart' as app;

/// Mount the unmodified dashboard so the sidebar, viewport and bindings match
/// the interactive app. Automation runs outside the measured operations.
Future<AppBenchmarkController> mountBenchmarkDashboard() async {
  WidgetsFlutterBinding.ensureInitialized();
  Levit.enableAutoLinking();
  runApp(const app.BenchmarkApp());
  await WidgetsBinding.instance.endOfFrame.timeout(const Duration(seconds: 5));
  AppBenchmarkController? controller;
  void visit(Element element) {
    final widget = element.widget;
    if (widget is Text && widget.data == 'Run All Benchmarks') {
      controller = element.levit.find<AppBenchmarkController>();
    }
    element.visitChildren(visit);
  }

  visit(WidgetsBinding.instance.rootElement!);
  if (controller == null) throw StateError('Dashboard did not mount');
  await Future<void>.delayed(const Duration(milliseconds: 300));
  return controller!;
}

Future<void> unmountBenchmarkDashboard() async {
  runApp(const SizedBox.shrink());
  await WidgetsBinding.instance.endOfFrame.timeout(const Duration(seconds: 5));
  await Levit.reset(force: true);
}
