import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import '../controllers/benchmark_controller.dart';
import '../benchmark_engine.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LScope(
      init: () => AppBenchmarkController(),
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _hasInitializedDrawer = false;

  @override
  Widget build(BuildContext context) {
    // Correct usage of context.levit.find
    final controller = context.levit.find<AppBenchmarkController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        // Auto-open drawer on first mobile load
        if (isMobile && !_hasInitializedDrawer) {
          _hasInitializedDrawer = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scaffoldKey.currentState?.openEndDrawer();
          });
        }

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: const Text('Levit Benchmarks'),
            actions: [
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                ),
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                ),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy Results',
                onPressed: () => controller.copyResults(),
              ),
            ],
          ),
          // Use EndDrawer for settings on Mobile to avoid conflict with potential nav drawer
          endDrawer: isMobile
              ? _SidebarContent(controller: controller, isInDrawer: true)
              : null,
          body: Row(
            children: [
              if (!isMobile)
                SizedBox(
                  width: 300,
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    child: _SidebarContent(controller: controller),
                  ),
                ),
              Expanded(
                child: Card(
                  margin:
                      const EdgeInsets.all(8).copyWith(left: isMobile ? 8 : 0),
                  child: _MainContent(controller: controller),
                ),
              ),
            ],
          ),
        );
      },
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Frameworks', style: Theme.of(context).textTheme.titleLarge),
          const Divider(),
          Expanded(
            child: LWatch(() {
              return ListView(
                children: Framework.values.map((fw) {
                  return CheckboxListTile(
                    title: Text(fw.label),
                    value: controller.selectedFrameworks.contains(fw),
                    onChanged: (val) => controller.toggleFramework(fw),
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
