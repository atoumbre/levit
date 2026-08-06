import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:levit_lints/src/rules.dart';

/// Entry point discovered by the Dart analysis server.
final plugin = LevitLintsPlugin();

/// Native analyzer plugin containing Levit lifecycle diagnostics.
class LevitLintsPlugin extends Plugin {
  @override
  String get name => 'Levit lints';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerLintRule(AvoidPlainLxStatusFields())
      ..registerLintRule(AvoidPreconstructedLevitPut())
      ..registerLintRule(MustCallSuperLevitLifecycle())
      ..registerLintRule(UnownedLevitResource());
  }
}
