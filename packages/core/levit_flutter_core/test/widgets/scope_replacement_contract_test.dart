import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class _Resource extends LevitScopeDisposable {
  _Resource(this.release, {this.fail = false});
  final Future<void> release;
  final bool fail;
  @override
  Future<void> onClose() async {
    await release;
    if (fail) throw StateError('cleanup failure');
  }
}

void main() {
  testWidgets('scope replacement drains old cleanup and coalesces rapid args', (
    tester,
  ) async {
    final release = Completer<void>();
    final lifecycle = LevitScopeLifecycleController();
    final initialized = <int>[];
    Widget build(int id) => LScope(
      lifecycle: lifecycle,
      args: [id],
      configure: (scope) {
        initialized.add(id);
        if (id == 1) scope.put(() => _Resource(release.future));
      },
      loading: (_) => const Text('closing', textDirection: TextDirection.ltr),
      child: Text('ready $id', textDirection: TextDirection.ltr),
    );
    await tester.pumpWidget(build(1));
    expect(find.text('ready 1'), findsOneWidget);
    await tester.pumpWidget(build(2));
    await tester.pumpWidget(build(3));
    expect(initialized, [1]);
    expect(find.text('closing'), findsOneWidget);
    release.complete();
    await tester.pumpAndSettle();
    expect(initialized, [1, 3]);
    expect(find.text('ready 3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await lifecycle.close();
  });

  testWidgets('obsolete initialization failure cannot close the replacement', (
    tester,
  ) async {
    final initialize = Completer<void>();
    final lifecycle = LevitScopeLifecycleController();
    final scopes = <LevitScope>[];
    Widget build(int id) => LAsyncScope(
      lifecycle: lifecycle,
      args: [id],
      configure: (scope) async {
        scopes.add(scope);
        if (id == 1) await initialize.future;
      },
      child: const Text('ready', textDirection: TextDirection.ltr),
    );
    await tester.pumpWidget(build(1));
    await tester.pumpWidget(build(2));
    initialize.completeError(StateError('obsolete'));
    await tester.pumpAndSettle();
    expect(scopes, hasLength(2));
    expect(scopes.first.isDisposed, isTrue);
    expect(scopes.last.isClosing, isFalse);
    expect(find.text('ready'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await lifecycle.close();
  });

  testWidgets('unmount completion includes pending initialization', (
    tester,
  ) async {
    final initialize = Completer<void>();
    final lifecycle = LevitScopeLifecycleController();
    await tester.pumpWidget(
      LAsyncScope(
        lifecycle: lifecycle,
        configure: (_) => initialize.future,
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    var closed = false;
    final cleanup = lifecycle.close().then((_) => closed = true);
    await tester.pump();
    expect(closed, isFalse);
    initialize.complete();
    await tester.pumpAndSettle();
    await cleanup;
    expect(closed, isTrue);
  });

  testWidgets('cleanup failure blocks replacement until explicit retry', (
    tester,
  ) async {
    final lifecycle = LevitScopeLifecycleController();
    var initialized = 0;
    Widget build(int id) => LScope(
      lifecycle: lifecycle,
      args: [id],
      configure: (scope) {
        initialized++;
        if (id == 1) {
          scope.put(() => _Resource(Future<void>.value(), fail: true));
        }
      },
      error: (_, error) =>
          const Text('failed', textDirection: TextDirection.ltr),
      child: const Text('ready', textDirection: TextDirection.ltr),
    );
    await tester.pumpWidget(build(1));
    await tester.pumpWidget(build(2));
    await tester.pumpAndSettle();
    expect(initialized, 1);
    expect(find.text('failed'), findsOneWidget);
    await lifecycle.retry();
    await tester.pumpAndSettle();
    expect(initialized, 2);
    expect(find.text('ready'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await lifecycle.close();
  });
}
