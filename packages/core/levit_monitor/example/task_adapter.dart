import 'package:levit/levit.dart';
import 'package:levit_monitor/levit_monitor.dart';

/// Optional application bridge: levit_monitor has no task-engine dependency.
/// Own the adapter after its borrowed engine so it unsubscribes before release.
class TaskMonitorAdapter implements LevitDisposable {
  final LevitTaskEngine engine;
  final String ownerPath;
  TaskMonitorAdapter(this.engine, {required this.ownerPath}) {
    engine.taskTree.addListener(_publish);
    _publish();
  }
  Map<String, Object?> _tree(LevitTaskTreeSnapshot group) => {
    'id': group.id,
    'name': group.name,
    'parentId': group.parentId,
    'isClosing': group.isClosing,
    'isComplete': group.isComplete,
    'pendingCount': group.pendingCount,
    'runningCount': group.runningCount,
    'deadline': group.deadline?.toIso8601String(),
    'cancellationReason': group.cancellationReason?.kind.name,
    'executionIds': group.executionIds,
    'children': group.children.map(_tree).toList(),
  };
  void _publish() => LevitMonitor.emitCustomEvent(
    namespace: 'levit.tasks',
    name: 'tree',
    attributes: {'ownerPath': ownerPath, 'tree': _tree(engine.taskTree.value)},
  );
  @override
  Future<void> dispose() async {
    engine.taskTree.removeListener(_publish);
    LevitMonitor.emitCustomEvent(
      namespace: 'levit.tasks',
      name: 'tree',
      attributes: {'ownerPath': ownerPath, 'closed': true},
    );
  }
}
