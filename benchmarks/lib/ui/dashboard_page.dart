import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import '../controllers/benchmark_controller.dart';
import '../benchmark_engine.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static final store = LevitStore((ref) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
    final hasInitializedDrawer = false.lx;
    final isMobile = false.lx;

    final controller = ref.put(() => AppBenchmarkController());

    // Declarative Effect: Triggered when isMobile OR initialized status changes
    ref.autoDispose(LxComputed(() {
      if (isMobile.value && !hasInitializedDrawer.value) {
        hasInitializedDrawer.value = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scaffoldKey.currentState?.openEndDrawer();
        });
      }
    }, eager: true));

    return (
      scaffoldKey: scaffoldKey,
      hasInitializedDrawer: hasInitializedDrawer,
      isMobile: isMobile,
      controller: controller,
    );
  });

  @override
  Widget build(BuildContext context) {
    return LScopedView.store(
      store,
      builder: (context, state) => LayoutBuilder(
        builder: (context, constraints) {
          state.isMobile.value = constraints.maxWidth < 800;
          final isMobile = state.isMobile.value;

          return Scaffold(
            key: state.scaffoldKey,
            appBar: AppBar(
              title: const Text('Levit Benchmarks'),
              actions: [
                if (isMobile)
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () =>
                        state.scaffoldKey.currentState?.openEndDrawer(),
                  ),
                if (isMobile)
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () =>
                        state.scaffoldKey.currentState?.openEndDrawer(),
                  ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy Results',
                  onPressed: () => state.controller.copyResults(),
                ),
              ],
            ),
            // Use EndDrawer for settings on Mobile to avoid conflict with potential nav drawer
            endDrawer: isMobile
                ? _SidebarContent(
                    controller: state.controller, isInDrawer: true)
                : null,
            body: Row(
              children: [
                if (!isMobile)
                  SizedBox(
                    width: 380,
                    child: Card(
                      margin: const EdgeInsets.all(8),
                      child: _SidebarContent(controller: state.controller),
                    ),
                  ),
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(8)
                        .copyWith(left: isMobile ? 8 : 0),
                    child: _MainContent(controller: state.controller),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  final AppBenchmarkController controller;
  final bool isInDrawer;

  const _SidebarContent({
    required this.controller,
    this.isInDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Frameworks', style: Theme.of(context).textTheme.titleLarge),
              Spacer(),
              TextButton(
                onPressed: () => controller.toggleAllFrameworks(true),
                child: Text("All"),
              ),
              TextButton(
                onPressed: () => controller.toggleAllFrameworks(false),
                child: Text("None"),
              ),
            ],
          ),
          LWatch(() {
            return Column(
              children: Framework.values.map((fw) {
                return CheckboxListTile(
                  title: Text(fw.label),
                  value: controller.selectedFrameworks.contains(fw),
                  onChanged: (val) => controller.toggleFramework(fw),
                );
              }).toList(),
            );
          }),
          Gap(16),
          Row(
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Benchmarks',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Spacer(),
              TextButton(
                onPressed: () => controller.toggleAllBenchmarks(true),
                child: Text("All"),
              ),
              TextButton(
                onPressed: () => controller.toggleAllBenchmarks(false),
                child: Text("None"),
              ),
            ],
          ),
          Expanded(
            child: LWatch(() {
              return ListView(
                children: controller.availableBenchmarks.map((bench) {
                  return CheckboxListTile(
                    title: Text(bench.name),
                    // subtitle: Text(bench.description,
                    //     maxLines: 1, overflow: TextOverflow.ellipsis),
                    value: controller.selectedBenchmarks.contains(bench),
                    onChanged: (val) => controller.toggleBenchmark(bench),
                  );
                }).toList(),
              );
            }),
          ),
          const Gap(20),
          LWatch(() {
            if (controller.isRunning.value) {
              return Column(
                children: [
                  LinearProgressIndicator(value: controller.progress.value),
                  const Gap(8),
                  Text(controller.currentStatus.value),
                ],
              );
            }
            return SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (isInDrawer) {
                    Navigator.of(context).pop();
                  }
                  controller.runAll();
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run All Benchmarks'),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MainContent extends StatelessWidget {
  final AppBenchmarkController controller;
  const _MainContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      // Active Benchmark Overlay
      if (controller.activeBenchmarkWidget.value != null) {
        return Stack(children: [
          // Dimmed background
          const Center(
            child: CircularProgressIndicator(),
          ),
          Container(color: Colors.white.withValues(alpha: 0.9)),
          // The actual widget
          Positioned.fill(
            child: Builder(builder: controller.activeBenchmarkWidget.value!),
          ),
          // Label
          const Positioned(
            top: 20,
            left: 20,
            child: Material(
              color: Colors.transparent,
              child: Text("Running UI Benchmark...",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
            ),
          )
        ]);
      }

      if (controller.results.isEmpty && !controller.isRunning.value) {
        return const Center(child: Text('Press Run to start benchmarks.'));
      }

      return ListView(
        padding: const EdgeInsets.all(16),
        children: controller.availableBenchmarks.map((bench) {
          final results = controller.results[bench.name] ?? [];
          if (results.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bench.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              Text(bench.description,
                  style: Theme.of(context).textTheme.bodySmall),
              const Gap(16),
              // Chart
              AspectRatio(
                aspectRatio: 2, // Widescreen chart
                child: _buildChart(results),
              ),
              const Gap(32),
            ],
          );
        }).toList(),
      );
    });
  }

  Widget _buildChart(List<BenchmarkResult> results) {
    if (results.isEmpty) return const SizedBox.shrink();

    final sorted = List<BenchmarkResult>.from(results)
      ..sort((a, b) => a.durationMs.compareTo(b.durationMs));

    final maxDuration = sorted.last.durationMs;
    final maxY = maxDuration == 0 ? 1.0 : maxDuration * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY.toDouble(),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < sorted.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(sorted[value.toInt()].framework.label,
                        style: const TextStyle(fontSize: 10)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barGroups: sorted.asMap().entries.map((entry) {
          final index = entry.key;
          final res = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: res.durationMs,
                color: res.success
                    ? _getColor(res.framework)
                    : Colors.red, // Red on error
                width: 20,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY.toDouble(),
                    color: Colors.grey.withValues(alpha: 0.1)),
              ),
            ],
            showingTooltipIndicators: [0],
          );
        }).toList(),
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(3)}ms',
                const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
      ),
    );
  }

  Color _getColor(Framework fw) {
    return switch (fw) {
      Framework.levit => Colors.blue,
      Framework.vanilla => Colors.grey,
      Framework.getx => Colors.purple,
      Framework.bloc => Colors.red,
      Framework.riverpod => Colors.teal,
    };
  }
}
