import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  runApp(const ScopePlaygroundApp());
}

class ScopePlaygroundApp extends StatelessWidget {
  const ScopePlaygroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ScopePlaygroundScreen(),
    );
  }
}

class WorkspaceCounterController extends LevitController {
  final String label;
  final count = 0.lx;

  WorkspaceCounterController(this.label);

  @override
  void onInit() {
    super.onInit();
    autoDispose(count);
  }

  void increment() {
    count.value++;
  }
}

class ScopePlaygroundScreen extends StatelessWidget {
  const ScopePlaygroundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scope Playground')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _WorkspacePanel(label: 'Design Team'),
            SizedBox(height: 16),
            _WorkspacePanel(label: 'Platform Team'),
          ],
        ),
      ),
    );
  }
}

class _WorkspacePanel extends StatelessWidget {
  final String label;

  const _WorkspacePanel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: LScope.put(
        () => WorkspaceCounterController(label),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                LView<WorkspaceCounterController>(
                  builder: (context, controller) => Row(
                    children: [
                      Text('Actions: ${controller.count.value}'),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: controller.increment,
                        child: const Text('Increment'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Each panel has its own scope and controller instance.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
