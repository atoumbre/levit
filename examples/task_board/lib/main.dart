import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  runApp(const TaskBoardExampleApp());
}

class TaskBoardExampleApp extends StatelessWidget {
  const TaskBoardExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TaskBoardScreen(),
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

class TaskBoardController extends LevitController {
  final tasks = LxList<TaskItem>().named('tasks');
  final query = ''.lx.named('query');

  late final TextEditingController addController =
      autoDispose(TextEditingController());
  late final TextEditingController searchController =
      autoDispose(TextEditingController());

  late final LxComputed<List<TaskItem>> filteredTasks;
  int _nextId = 1;

  @override
  void onInit() {
    super.onInit();
    autoDispose(tasks);
    autoDispose(query);

    filteredTasks = autoDispose(
      LxComputed(() {
        final search = query.value.trim().toLowerCase();
        if (search.isEmpty) return tasks.toList(growable: false);
        return tasks
            .where((item) => item.title.toLowerCase().contains(search))
            .toList(growable: false);
      }).named('filteredTasks'),
    );

    add('Plan milestone 0.1.0');
    add('Polish docs and examples');
    add('Publish benchmark report');
  }

  void add(String title) {
    final value = title.trim();
    if (value.isEmpty) return;
    tasks.add(TaskItem(id: _nextId++, title: value));
  }

  void toggle(int id) {
    final index = tasks.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final current = tasks[index];
    tasks[index] = current.copyWith(done: !current.done);
  }
}

class TaskBoardScreen extends StatelessWidget {
  const TaskBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LScopedView.put(
      () => TaskBoardController(),
      builder: (context, controller) => Scaffold(
        appBar: AppBar(title: const Text('Levit Task Board')),
        body: Column(
          children: [
            _Toolbar(controller: controller),
            const Divider(height: 0),
            Expanded(
              child: LWatch(() {
                final items = controller.filteredTasks.value;
                if (items.isEmpty) {
                  return const Center(child: Text('No matching tasks'));
                }
                return ListView(
                  children: [
                    for (final item in items)
                      CheckboxListTile(
                        value: item.done,
                        title: Text(item.title),
                        onChanged: (_) => controller.toggle(item.id),
                      ),
                  ],
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LSelectorBuilder(
                () => '${controller.tasks.where((item) => item.done).length}'
                    '/${controller.tasks.length} completed',
                (summary) => Text(summary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final TaskBoardController controller;

  const _Toolbar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: controller.addController,
            decoration: InputDecoration(
              hintText: 'Add a task',
              suffixIcon: IconButton(
                onPressed: () {
                  controller.add(controller.addController.text);
                  controller.addController.clear();
                },
                icon: const Icon(Icons.add),
              ),
            ),
            onSubmitted: (_) {
              controller.add(controller.addController.text);
              controller.addController.clear();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller.searchController,
            decoration: const InputDecoration(
              hintText: 'Filter tasks',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => controller.query.value = value,
          ),
        ],
      ),
    );
  }
}
