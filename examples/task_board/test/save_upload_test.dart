import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_testing.dart';
import 'package:levit_example_task_board/save_upload.dart';

class ControlledRepository extends UploadRepository {
  final started = Completer<void>();
  final finish = Completer<void>();
  final fail = Completer<void>();
  final bool failUpload;
  ControlledRepository({this.failUpload = false});
  var active = 0;
  @override
  Future<void> upload(String name, LevitTaskContext context) async {
    active++;
    if (active == 2) started.complete();
    try {
      if (failUpload && name == 'cover') {
        await fail.future;
        throw StateError('upload failed');
      }
      await context.cancelled;
      context.throwIfCancelled();
    } finally {
      await finish.future;
      events.add('drained:$name');
    }
  }
}

void main() {
  testWidgets('buttons observe cancellation and feature unmount completes', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SaveUploadPage()));
    await tester.pumpAndSettle();
    final controller = tester
        .element(find.text('Ready'))
        .levit
        .find<SaveUploadController>();
    await tester.tap(find.text('Save with attachments'));
    await tester.pump();
    expect(find.text('Uploading'), findsOneWidget);
    await tester.tap(find.text('Cancel workflow'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled after cleanup'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await controller.scope!.dispose();
    expect(controller.repository.closed, isTrue);
  });

  test(
    'owner waits for cancelled upload finally before repository close',
    () async {
      final scope = LevitTestScope();
      addTearDown(scope.close);
      final repository = ControlledRepository();
      final controller = scope.scope.put(
        () => SaveUploadController(repository),
      );
      final saving = controller.saveAndUpload();
      await repository.started.future;
      var done = false;
      final closing = scope.close().then((_) => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      expect(repository.closed, isFalse);
      repository.finish.complete();
      await saving;
      await closing;
      expect(repository.events.last, 'repository closed');
      expect(
        repository.events.where((e) => e.startsWith('drained:')).length,
        2,
      );
    },
  );

  test('failed attachment cancels sibling but root remains usable', () async {
    final scope = LevitTestScope();
    addTearDown(scope.close);
    final repository = ControlledRepository(failUpload: true);
    final controller = scope.scope.put(() => SaveUploadController(repository));
    final saving = controller.saveAndUpload();
    await repository.started.future;
    repository.fail.complete();
    repository.finish.complete();
    await saving;
    expect(controller.status.value, startsWith('Save failed:'));
    expect(controller.busy.value, isFalse);
    expect(await controller.runTask((_) => 42), 42);
    expect(repository.events.where((e) => e.startsWith('drained:')).length, 2);
  });

  test('successful save publishes one completed workflow', () async {
    final scope = LevitTestScope();
    addTearDown(scope.close);
    final controller = scope.scope.put(
      () => SaveUploadController(UploadRepository()),
    );
    await controller.saveAndUpload();
    expect(controller.status.value, 'Saved and uploaded');
    expect(controller.repository.events.first, 'saved');
    expect(
      controller.repository.events
          .where((e) => e.startsWith('uploaded:'))
          .length,
      2,
    );
  });
}
