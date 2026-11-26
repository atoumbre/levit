/// Native analyzer plugin entry point for `levit_lints`.
///
/// The Dart analysis server discovers this library and its top-level [plugin]
/// instance automatically when `levit_lints` is configured under `plugins:` in
/// a workspace's root `analysis_options.yaml`.
library;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:levit_lints/src/rules.dart';

/// Top-level plugin entry point discovered by the Dart analysis server.
///
/// {@category Plugin}
final plugin = LevitLintsPlugin();

/// Native Dart analyzer plugin registering all Levit diagnostics.
///
/// Registers seven rules when loaded by the analysis server:
/// - [AvoidPlainLxStatusFields] (`avoid_plain_lx_status_fields`)
/// - [AvoidPreconstructedLevitPut] (`avoid_preconstructed_levit_put`)
/// - [MustCallSuperLevitLifecycle] (`must_call_super_levit_lifecycle`)
/// - [UnownedLevitResource] (`unowned_levit_resource`)
/// - [AwaitLevitLifecycle] (`await_levit_lifecycle`)
/// - [AvoidGlobalLevitInWidgets] (`avoid_global_levit_in_widgets`)
/// - [DiscardedLevitFuture] (`discarded_levit_future`)
///
/// Individual diagnostics are toggled under `plugins.levit_lints.diagnostics`
/// in the consuming project's root `analysis_options.yaml`.
///
/// {@category Plugin}
class LevitLintsPlugin extends Plugin {
  @override
  String get name => 'Levit lints';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerLintRule(AvoidPlainLxStatusFields())
      ..registerLintRule(AvoidPreconstructedLevitPut())
      ..registerLintRule(MustCallSuperLevitLifecycle())
      ..registerLintRule(UnownedLevitResource())
      ..registerLintRule(AwaitLevitLifecycle())
      ..registerLintRule(AvoidGlobalLevitInWidgets())
      ..registerLintRule(DiscardedLevitFuture());
  }
}
