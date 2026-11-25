import 'dart:async';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_flutter/tasks.dart';

void main() {
  Levit.enableAutoLinking();
  runApp(const MaterialApp(home: SaveUploadPage()));
}

/// Application IO boundary; the controller owns it until every upload drains.
class UploadRepository implements LevitDisposable {
  final events = <String>[];
  bool closed = false;
  Future<void> save(LevitTaskContext context) async {
    context.throwIfCancelled();
    events.add('saved');
  }

  Future<void> upload(String name, LevitTaskContext context) async {
    events.add('start:$name');
    final transferred = Completer<void>();
    final transferTimer = Timer(
      const Duration(milliseconds: 500),
      transferred.complete,
    );
    try {
      // The IO adapter must cancel its actual operation, then await cleanup.
      await Future.any([transferred.future, context.cancelled]);
      context.throwIfCancelled();
      events.add('uploaded:$name');
    } finally {
      transferTimer.cancel();
      if (!transferred.isCompleted) transferred.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      events.add('drained:$name');
    }
  }

  @override
  Future<void> dispose() async {
    closed = true;
    events.add('repository closed');
  }
}

class SaveUploadController extends LevitController with LevitTasksMixin {
  SaveUploadController(this.repository);
  final UploadRepository repository;
  final status = 'Ready'.lx;
  final busy = false.lx;
  LevitTaskGroup? _workflow;

  @override
  void onInit() {
    super.onInit();
    own(repository);
    own(status);
    own(busy);
  }

  Future<void> saveAndUpload() async {
    if (_workflow != null || isClosed) return;
    final group = _workflow = LevitTaskGroup(
      engine: taskEngine,
      name: 'save and upload',
    );
    busy.value = true;
    status.value = 'Saving';
    try {
      await group.run((workflow) async {
        await workflow.schedule(repository.save, id: 'save');
        status.value = 'Uploading';
        await workflow.runGroup((uploads) {
          // Group completion observes failures and awaits all descendant finally blocks.
          for (final name in ['cover', 'attachment']) {
            uploads.submit(
              (context) => repository.upload(name, context),
              id: name,
            );
          }
        }, name: 'uploads');
      });
      if (!isClosed) status.value = 'Saved and uploaded';
    } on LevitTaskCancelledException {
      if (!isClosed) status.value = 'Cancelled after cleanup';
    } catch (error) {
      if (!isClosed) status.value = 'Save failed: $error';
    } finally {
      _workflow = null;
      if (!isClosed) busy.value = false;
    }
  }

  void cancel() => _workflow?.cancel();
}

class SaveUploadPage extends StatelessWidget {
  const SaveUploadPage({super.key});
  @override
  Widget build(BuildContext context) => LScopedView<SaveUploadController>.put(
    () => SaveUploadController(UploadRepository()),
    autoWatch: false,
    builder: (context, controller) => Scaffold(
      appBar: AppBar(title: const Text('Save and upload')),
      body: Center(
        child: LWatch(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(controller.status.value),
              FilledButton(
                onPressed: controller.busy.value
                    ? null
                    : controller.saveAndUpload,
                child: const Text('Save with attachments'),
              ),
              TextButton(
                onPressed: controller.busy.value ? controller.cancel : null,
                child: const Text('Cancel workflow'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
