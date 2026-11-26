import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../controller/inspector_controller.dart';

/// Displays active structured task trees bridged via `levit.tasks/tree` events.
class TaskTreeView extends StatelessWidget {
  final LevitInspectorController controller;

  const TaskTreeView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      controller.revision();
      final trees = controller.snapshot.taskTrees;
      if (trees.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No active task trees recorded.\n'
              'Bridge LevitTaskMiddleware events to LevitMonitor.emitCustomEvent '
              '(namespace: "levit.tasks", name: "tree") to inspect live task groups here.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }

      const encoder = JsonEncoder.withIndent('  ');
      final entries =
          trees.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final data = entry.value;
          final tasks = (data['tasks'] as List<dynamic>?) ?? const [];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(Icons.playlist_play, size: 20),
              title: Text(entry.key),
              subtitle: Text(
                '${tasks.length} task(s) • status: ${data['status'] ?? 'active'}',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      encoder.convert(data),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}
