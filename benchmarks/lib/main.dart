import 'package:flutter/material.dart';
import 'package:levit_dart/levit_dart.dart';

import 'ui/dashboard_page.dart';

void main() {
  // LevitMonitor.attach(transport: IsolateConsoleTransport());

  Levit.enableAutoLinking();

  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Levit Benchmarks',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}
