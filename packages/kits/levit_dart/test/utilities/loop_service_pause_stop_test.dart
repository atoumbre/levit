import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  test('registerService replaces existing service and tracks permanence', () {
    final engine = LevitLoopEngine();
    final first = _TestService();
    final second = _TestService();

    engine.registerService('svc', first, permanent: true);
    engine.registerService('svc', second);

    expect(first.stopCount, 1);

    engine.pauseAllServices();
    engine.resumeAllServices();

    expect(second.pauseCount, 1);
    expect(second.resumeCount, 1);

    engine.dispose();
    expect(second.stopCount, 1);
  });

  test('pauseAllServices and resumeAllServices respect permanent services', () {
    final engine = LevitLoopEngine();
    final permanent = _TestService();
    final regular = _TestService();

    engine.registerService('permanent', permanent, permanent: true);
    engine.registerService('regular', regular);

    engine.pauseAllServices();
    engine.resumeAllServices();

    expect(permanent.pauseCount, 0);
    expect(permanent.resumeCount, 0);
    expect(regular.pauseCount, 1);
    expect(regular.resumeCount, 1);

    engine.pauseAllServices(force: true);
    engine.resumeAllServices(force: true);

    expect(permanent.pauseCount, 1);
    expect(permanent.resumeCount, 1);

    engine.dispose();
  });
}

class _TestService implements StoppableService {
  @override
  final status = LxVar<LxStatus<dynamic>>(LxIdle());

  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;

  @override
  void pause() => pauseCount++;

  @override
  void resume() => resumeCount++;

  @override
  void start() {}

  @override
  void stop() => stopCount++;
}
