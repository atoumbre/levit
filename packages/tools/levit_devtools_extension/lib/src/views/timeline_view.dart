import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_monitor/spi.dart';

import '../controller/inspector_controller.dart';

/// Live filterable timeline of redacted [LevitEventEnvelope]s.
class TimelineView extends StatelessWidget {
  final LevitInspectorController controller;

  const TimelineView({super.key, required this.controller});

  static const _categories = <String?>[
    null,
    'state',
    'di',
    'log',
    'custom',
    'error',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 16),
                    hintText: 'Search timeline events...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => controller.timelineSearch.value = v,
                ),
              ),
              LWatch(() {
                final selected = controller.timelineCategory();
                return Wrap(
                  spacing: 6,
                  children: [
                    for (final category in _categories)
                      ChoiceChip(
                        label: Text(category ?? 'All'),
                        selected: selected == category,
                        visualDensity: VisualDensity.compact,
                        onSelected:
                            (_) => controller.timelineCategory.value = category,
                      ),
                  ],
                );
              }),
              OutlinedButton.icon(
                onPressed: controller.clearLocalTimeline,
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LWatch(() {
            controller.revision();
            final events = controller.filteredTimeline;
            if (events.isEmpty) {
              return const Center(
                child: Text('No timeline events match the current filter.'),
              );
            }

            final selectedSeq = controller.selectedEventSeq();
            final selected =
                events.where((e) => e.seq == selectedSeq).firstOrNull ??
                events.first;

            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ListView.separated(
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final envelope = events[index];
                      return ListTile(
                        dense: true,
                        selected: envelope.seq == selected.seq,
                        title: Text(
                          '#${envelope.seq} • ${envelope.type}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _summarize(envelope),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Chip(
                          label: Text(
                            envelope.category,
                            style: const TextStyle(fontSize: 10),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onTap:
                            () =>
                                controller.selectedEventSeq.value =
                                    envelope.seq,
                      );
                    },
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(flex: 2, child: _EventDetailPane(envelope: selected)),
              ],
            );
          }),
        ),
      ],
    );
  }

  String _summarize(LevitEventEnvelope envelope) {
    final data = envelope.data;
    if (envelope.type == 'state_change') {
      final name = data['name'] ?? data['reactiveId'];
      return '$name: ${data['oldValue']} → ${data['newValue']}';
    }
    if (data['scopeName'] != null) {
      return 'scope: ${data['scopeName']}'
          '${data['key'] != null ? ' • ${data['key']}' : ''}';
    }
    if (data['error'] != null) return 'error: ${data['error']}';
    if (data['name'] != null) return '${data['name']}';
    return data['timestamp']?.toString() ?? '';
  }
}

class _EventDetailPane extends StatelessWidget {
  final LevitEventEnvelope envelope;

  const _EventDetailPane({required this.envelope});

  @override
  Widget build(BuildContext context) {
    const encoder = JsonEncoder.withIndent('  ');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Event #${envelope.seq} (${envelope.type})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SelectableText(
          encoder.convert(envelope.toJson()),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ],
    );
  }
}
