import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_monitor/spi.dart';

import '../controller/inspector_controller.dart';

/// Displays deterministic runtime anomaly findings from
/// [LevitSnapshotDiagnostics].
class DiagnosticsView extends StatelessWidget {
  final LevitInspectorController controller;

  const DiagnosticsView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      controller.revision();
      final threshold = controller.highListenerThreshold();
      final findings = controller.findings;

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  'Findings (${findings.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                const Text('High listener threshold: '),
                DropdownButton<int>(
                  value: threshold,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50 (default)')),
                    DropdownMenuItem(value: 100, child: Text('100')),
                  ],
                  onChanged: (next) {
                    if (next != null) {
                      controller.highListenerThreshold.value = next;
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                findings.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 36,
                            color: Colors.green,
                          ),
                          SizedBox(height: 8),
                          Text('No runtime anomalies detected.'),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: findings.length,
                      itemBuilder: (context, index) {
                        final finding = findings[index];
                        return _FindingCard(
                          finding: finding,
                          controller: controller,
                        );
                      },
                    ),
          ),
        ],
      );
    });
  }
}

class _FindingCard extends StatelessWidget {
  final LevitDiagnosticFinding finding;
  final LevitInspectorController controller;

  const _FindingCard({required this.finding, required this.controller});

  @override
  Widget build(BuildContext context) {
    const encoder = JsonEncoder.withIndent('  ');
    final (icon, color) = switch (finding.severity) {
      LevitDiagnosticSeverity.error => (Icons.error_outline, Colors.red),
      LevitDiagnosticSeverity.warning => (
        Icons.warning_amber_rounded,
        Colors.amber.shade700,
      ),
      LevitDiagnosticSeverity.info => (Icons.info_outline, Colors.blue),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  finding.code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (finding.code == 'unowned_reactives')
                  TextButton(
                    onPressed: () {
                      controller.reactiveFilter.value =
                          ReactiveFilterMode.unowned;
                      controller.activeTabIndex.value = 1;
                    },
                    child: const Text('Show Unowned'),
                  ),
                if (finding.code == 'high_listener_count')
                  TextButton(
                    onPressed: () {
                      controller.reactiveFilter.value =
                          ReactiveFilterMode.highListeners;
                      controller.activeTabIndex.value = 1;
                    },
                    child: const Text('Show High Listeners'),
                  ),
                if (finding.code == 'closing_scopes' ||
                    finding.code == 'pending_initializations')
                  TextButton(
                    onPressed: () => controller.activeTabIndex.value = 0,
                    child: const Text('Open Scopes'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(finding.message),
            if (finding.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  encoder.convert(finding.details),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
