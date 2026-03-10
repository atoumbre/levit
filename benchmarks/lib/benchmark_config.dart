class BenchmarkProfile {
  final int asyncComputedIterations;
  final int complexGraphIterations;
  final int batchIterations;
  final int fanInInputs;
  final int fanOutDependents;
  final int rapidMutationIterations;
  final int scopedDiIterations;
  final int computedChainIterations;
  final int computedChainRunIterations;

  const BenchmarkProfile({
    required this.asyncComputedIterations,
    required this.complexGraphIterations,
    required this.batchIterations,
    required this.fanInInputs,
    required this.fanOutDependents,
    required this.rapidMutationIterations,
    required this.scopedDiIterations,
    required this.computedChainIterations,
    required this.computedChainRunIterations,
  });
}

class BenchmarkConfig {
  static const BenchmarkProfile productionProfile = BenchmarkProfile(
    asyncComputedIterations: 100,
    complexGraphIterations: 10000,
    batchIterations: 1000,
    fanInInputs: 1000,
    fanOutDependents: 1000,
    rapidMutationIterations: 1000000,
    scopedDiIterations: 1000,
    computedChainIterations: 1000,
    computedChainRunIterations: 1000,
  );

  static const BenchmarkProfile testProfile = BenchmarkProfile(
    asyncComputedIterations: 20,
    complexGraphIterations: 500,
    batchIterations: 200,
    fanInInputs: 100,
    fanOutDependents: 100,
    rapidMutationIterations: 20000,
    scopedDiIterations: 200,
    computedChainIterations: 80,
    computedChainRunIterations: 80,
  );

  static BenchmarkProfile _profile = productionProfile;
  static String _profileName = 'production';

  static int get asyncComputedIterations => _profile.asyncComputedIterations;
  static int get complexGraphIterations => _profile.complexGraphIterations;
  static int get batchIterations => _profile.batchIterations;
  static int get fanInInputs => _profile.fanInInputs;
  static int get fanOutDependents => _profile.fanOutDependents;
  static int get rapidMutationIterations => _profile.rapidMutationIterations;
  static int get scopedDiIterations => _profile.scopedDiIterations;
  static int get computedChainIterations => _profile.computedChainIterations;
  static int get computedChainRunIterations =>
      _profile.computedChainRunIterations;

  static void useProductionProfile() {
    _profile = productionProfile;
    _profileName = 'production';
  }

  static void useTestProfile() {
    _profile = testProfile;
    _profileName = 'test';
  }

  static String get profileName => _profileName;
}
