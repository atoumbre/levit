import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  runApp(const TaskBoardApp());
}

class TaskBoardApp extends StatelessWidget {
  const TaskBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TaskBoardPage(),
    );
  }
}

class TaskItem {
  final int id;
  final String title;
  final bool done;

  const TaskItem({
    required this.id,
    required this.title,
    this.done = false,
  });

  TaskItem copyWith({
    String? title,
    bool? done,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      done: done ?? this.done,
    );
  }
}

enum TaskFilter { all, active, done }

class TaskBoardController extends LevitController {
  final tasks = LxList<TaskItem>().named('tasks');
  final filter = TaskFilter.all.lx.named('filter');
  final isBulkUpdating = false.lx.named('isBulkUpdating');
  final saveStatus = LxVar<LxStatus<String>>(LxIdle<String>()).named(
    'saveStatus',
  );

  late final LxComputed<int> completedCount;
  late final LxComputed<List<TaskItem>> visibleTasks;
  int _nextId = 1;

  @override
  void onInit() {
    super.onInit();
    autoDispose(tasks);
    autoDispose(filter);
    autoDispose(isBulkUpdating);
    autoDispose(saveStatus);

    completedCount = autoDispose(
      LxComputed(() => tasks.where((task) => task.done).length).named(
        'completedCount',
      ),
    );

    visibleTasks = autoDispose(
      LxComputed(() {
        return switch (filter.value) {
          TaskFilter.all => tasks.toList(growable: false),
          TaskFilter.active =>
            tasks.where((task) => !task.done).toList(growable: false),
          TaskFilter.done =>
            tasks.where((task) => task.done).toList(growable: false),
        };
      }).named('visibleTasks'),
    );

    addTask('Document architecture decisions');
    addTask('Write widget tests');
    addTask('Ship 0.1.0 release notes');
    toggleTask(2);
  }

  void setFilter(TaskFilter nextFilter) {
    filter.value = nextFilter;
  }

  void addTask(String title) {
    final normalized = title.trim();
    if (normalized.isEmpty) return;

    tasks.add(
      TaskItem(id: _nextId++, title: normalized),
    );
  }

  void toggleTask(int id) {
    final index = tasks.indexWhere((task) => task.id == id);
    if (index == -1) return;

    final current = tasks[index];
    tasks[index] = current.copyWith(done: !current.done);
  }

  void clearCompleted() {
    tasks.removeWhere((task) => task.done);
  }

  Future<void> markAll({required bool done}) async {
    if (tasks.isEmpty) return;
    isBulkUpdating.value = true;

    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (var index = 0; index < tasks.length; index++) {
      tasks[index] = tasks[index].copyWith(done: done);
    }
    isBulkUpdating.value = false;
  }

  Future<void> saveBoard() async {
    final lastMessage = saveStatus.value.lastValue;
    saveStatus.value = LxWaiting(lastMessage);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (tasks.isEmpty) {
      saveStatus.value = LxError(
        'Add at least one task before saving.',
        null,
        lastMessage,
      );
      return;
    }

    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    saveStatus.value = LxSuccess(
      'Saved ${tasks.length} tasks at $timestamp.',
    );
  }
}

class TaskBoardPage extends StatelessWidget {
  const TaskBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LScopedView.put(
      () => TaskBoardController(),
      builder: (context, controller) => Scaffold(
        appBar: AppBar(
          title: const Text('Levit Task Board'),
          actions: [
            IconButton(
              onPressed: controller.saveBoard,
              icon: const Icon(Icons.save),
              tooltip: 'Save',
            ),
          ],
        ),
        body: Column(
          children: [
            const _AddTaskBar(),
            const SizedBox(height: 8),
            LBuilder<TaskFilter>(
              controller.filter,
              (selected) => Wrap(
                spacing: 8,
                children: [
                  for (final option in TaskFilter.values)
                    ChoiceChip(
                      label: Text(option.name),
                      selected: option == selected,
                      onSelected: (_) => controller.setFilter(option),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            LSelectorBuilder(
              () =>
                  '${controller.completedCount.value}/${controller.tasks.length} completed',
              (summary) => Text(summary),
            ),
            const SizedBox(height: 8),
            LBuilder<bool>(
              controller.isBulkUpdating,
              (isBusy) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.tonal(
                    onPressed:
                        isBusy ? null : () => controller.markAll(done: true),
                    child: const Text('Mark all done'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed:
                        isBusy ? null : () => controller.markAll(done: false),
                    child: const Text('Mark all active'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: controller.clearCompleted,
                    child: const Text('Clear completed'),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: LWatch(
                () {
                  final visibleTasks = controller.visibleTasks.value;
                  if (visibleTasks.isEmpty) {
                    return const Center(
                      child: Text('No tasks in this filter.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: visibleTasks.length,
                    itemBuilder: (context, index) {
                      final task = visibleTasks[index];
                      return CheckboxListTile(
                        key: ValueKey('task_${task.id}'),
                        value: task.done,
                        title: Text(task.title),
                        onChanged: (_) => controller.toggleTask(task.id),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: LStatusBuilder<String>(
                controller.saveStatus,
                onIdle: () => const Text('No save operation yet.'),
                onWaiting: () => const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Saving...'),
                  ],
                ),
                onSuccess: (message) => Text(
                  message,
                  style: const TextStyle(color: Colors.green),
                ),
                onError: (error, _) => Text(
                  error.toString(),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTaskBar extends StatefulWidget {
  const _AddTaskBar();

  @override
  State<_AddTaskBar> createState() => _AddTaskBarState();
}

class _AddTaskBarState extends State<_AddTaskBar> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit(TaskBoardController controller) {
    controller.addTask(_textController.text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.levit.find<TaskBoardController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Add a task',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(controller),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () => _submit(controller),
            icon: const Icon(Icons.add_task),
          ),
        ],
      ),
    );
  }
}
