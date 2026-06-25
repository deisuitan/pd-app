import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/pd_session.dart';
import '../models/weight_record.dart';
import '../models/blood_pressure_record.dart';
import '../models/urine_record.dart';
import '../models/bowel_record.dart';
import '../widgets/session_card.dart';
import '../widgets/session_form.dart';
import '../widgets/urine_form.dart';
import '../widgets/bowel_form.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _periodDays = 7;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: _periodDays));

    final sessions = provider.sessions
        .where((s) => DateTime.parse(s.date).isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.fillStartTime.compareTo(a.fillStartTime));

    final weightRecords = provider.weightRecords
        .where((r) => DateTime.parse(r.date).isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final bloodPressureRecords = provider.bloodPressureRecords
        .where((r) => DateTime.parse(r.date).isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final urineRecords = provider.urineRecords
        .where((r) => DateTime.parse(r.date).isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    final urineRecordsAsc = List<UrineRecord>.from(urineRecords)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    final bowelRecords = provider.bowelRecords
        .where((r) => DateTime.parse(r.date).isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    return Scaffold(
      appBar: AppBar(title: const Text('履歴・グラフ')),
      body: CustomScrollView(
        slivers: [
          // 期間フィルター
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [7, 30, 90].map((days) {
                  final selected = _periodDays == days;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(days == 7 ? '1週間' : days == 30 ? '1ヶ月' : '3ヶ月'),
                      selected: selected,
                      onSelected: (_) => setState(() => _periodDays = days),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // 除水量グラフ
          if (sessions.isNotEmpty)
            SliverToBoxAdapter(
              child: _UFChart(sessions: sessions, days: _periodDays),
            ),

          // 体重グラフ または 空状態メッセージ
          SliverToBoxAdapter(
            child: weightRecords.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      '体重を記録するとグラフが表示されます',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4),
                          ),
                    ),
                  )
                : _WeightChart(records: weightRecords),
          ),

          // 血圧グラフ または 空状態メッセージ
          SliverToBoxAdapter(
            child: bloodPressureRecords.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      '血圧を記録するとグラフが表示されます',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4),
                          ),
                    ),
                  )
                : _BloodPressureChart(records: bloodPressureRecords),
          ),

          // 排尿量グラフ または 空状態メッセージ
          SliverToBoxAdapter(
            child: urineRecordsAsc.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      '排尿量を記録するとグラフが表示されます',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4),
                          ),
                    ),
                  )
                : _UrineChart(records: urineRecordsAsc),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          const SliverToBoxAdapter(child: Divider(height: 1)),

          // セッション一覧
          if (sessions.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    '記録がありません',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4),
                        ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final session = sessions[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (index == 0 || sessions[index - 1].date != session.date)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, top: 4),
                            child: Text(
                              DateFormat('M月d日（E）', 'ja')
                                  .format(DateTime.parse(session.date)),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        SessionCard(
                          session: session,
                          onEdit: () => showSessionForm(context, existing: session),
                          onDelete: () => _confirmDelete(context, session.id),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                  childCount: sessions.length,
                ),
              ),
            ),

          // お通じ記録一覧
          if (bowelRecords.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.wc, color: Colors.brown, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'お通じの記録',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final record = bowelRecords[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (index == 0 ||
                            bowelRecords[index - 1].date != record.date)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 4, top: 8),
                            child: Text(
                              DateFormat('M月d日（E）', 'ja')
                                  .format(DateTime.parse(record.date)),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Colors.brown,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.wc,
                                color: Colors.brown, size: 20),
                            title: Text(
                              record.consistency.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              DateFormat('HH:mm').format(record.recordedAt) +
                                  (record.note != null
                                      ? '　${record.note}'
                                      : ''),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => showBowelForm(
                                  context, record.date, record),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  childCount: bowelRecords.length,
                ),
              ),
            ),
          ],

          // 排尿量記録一覧
          if (urineRecords.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.water_drop, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '排尿量の記録',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final record = urineRecords[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (index == 0 ||
                            urineRecords[index - 1].date != record.date)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 4, top: 8),
                            child: Text(
                              DateFormat('M月d日（E）', 'ja')
                                  .format(DateTime.parse(record.date)),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.water_drop_outlined,
                                color: Colors.blue, size: 20),
                            title: Text(
                              '${record.urineVolumeMl} mL',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              DateFormat('HH:mm').format(record.recordedAt) +
                                  (record.note != null ? '　${record.note}' : ''),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () =>
                                  showUrineForm(context, record.date, record),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  childCount: urineRecords.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('記録を削除'),
        content: const Text('この記録を削除しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AppProvider>().deleteSession(id);
    }
  }
}

// ─── 除水量グラフ ────────────────────────────────────────────────

class _UFChart extends StatelessWidget {
  final List<PDSession> sessions;
  final int days;

  const _UFChart({required this.sessions, required this.days});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Map<String, int> dailyUF = {};
    for (final s in sessions) {
      dailyUF[s.date] = (dailyUF[s.date] ?? 0) + (s.ultrafiltration ?? 0);
    }
    final sorted = dailyUF.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sorted.isEmpty) return const SizedBox.shrink();

    final spots = sorted.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value.toDouble());
    }).toList();

    return SizedBox(
      height: 160,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
        child: LineChart(
          LineChartData(
            minY: (spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 100)
                .clamp(-600, 0),
            gridData: FlGridData(
              show: true,
              horizontalInterval: 200,
              getDrawingHorizontalLine: (_) => FlLine(
                color: cs.onSurface.withOpacity(0.06),
                strokeWidth: 1,
              ),
              drawVerticalLine: false,
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (val, _) => Text(
                    '${val.toInt()}',
                    style: TextStyle(
                        fontSize: 9, color: cs.onSurface.withOpacity(0.4)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: sorted.length > 14 ? 7 : 1,
                  getTitlesWidget: (val, _) {
                    final idx = val.toInt();
                    if (idx < 0 || idx >= sorted.length) {
                      return const SizedBox.shrink();
                    }
                    final date = DateTime.parse(sorted[idx].key);
                    return Text(
                      DateFormat('M/d').format(date),
                      style: TextStyle(
                          fontSize: 9, color: cs.onSurface.withOpacity(0.4)),
                    );
                  },
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            rangeAnnotations: RangeAnnotations(
              horizontalRangeAnnotations: [
                HorizontalRangeAnnotation(
                  y1: 100,
                  y2: 500,
                  color: Colors.green.withOpacity(0.07),
                ),
              ],
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: cs.primary,
                barWidth: 2,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                    radius: 4,
                    color: spot.y < 0 ? Colors.red : cs.primary,
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: cs.primary.withOpacity(0.06),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 排尿量グラフ ────────────────────────────────────────────────

class _UrineChart extends StatelessWidget {
  final List<UrineRecord> records;

  const _UrineChart({required this.records});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 日別合計
    final Map<String, int> dailyTotal = {};
    for (final r in records) {
      dailyTotal[r.date] = (dailyTotal[r.date] ?? 0) + r.urineVolumeMl;
    }
    final sorted = dailyTotal.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sorted.isEmpty) return const SizedBox.shrink();

    final spots = sorted.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value.toDouble());
    }).toList();

    final maxVal = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(
                '排尿量 (mL/日)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.5),
                    ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 20,
                height: 2,
                color: Colors.blue.withOpacity(0.4),
              ),
              const SizedBox(width: 4),
              Text(
                '500mL目安',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.blue.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 24, 8),
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: (maxVal > 500 ? maxVal + 100 : 700).toDouble(),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 200,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: cs.onSurface.withOpacity(0.06),
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 200,
                      getTitlesWidget: (val, _) => Text(
                        '${val.toInt()}',
                        style: TextStyle(
                            fontSize: 9, color: cs.onSurface.withOpacity(0.4)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: sorted.length > 14 ? 7 : 1,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= sorted.length) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime.parse(sorted[idx].key);
                        return Text(
                          DateFormat('M/d').format(date),
                          style: TextStyle(
                              fontSize: 9,
                              color: cs.onSurface.withOpacity(0.4)),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                // 500mL 目安ライン
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 500,
                      color: Colors.blue.withOpacity(0.35),
                      strokeWidth: 1.5,
                      dashArray: [4, 4],
                    ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.blue,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.06),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 血圧グラフ ──────────────────────────────────────────────────

class _BloodPressureChart extends StatelessWidget {
  final List<BloodPressureRecord> records;

  const _BloodPressureChart({required this.records});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Map<String, (int systolic, int diastolic)> dailyRep = {};
    for (final r in records) {
      final existing = dailyRep[r.date];
      if (existing == null) {
        dailyRep[r.date] = (r.systolic, r.diastolic);
      } else {
        final prevIsMorning = records
            .where((x) => x.date == r.date)
            .where((x) => x.systolic == existing.$1 && x.diastolic == existing.$2)
            .any((x) => x.measuredAt.hour >= 6 && x.measuredAt.hour < 10);
        final thisIsMorning = r.measuredAt.hour >= 6 && r.measuredAt.hour < 10;
        if (thisIsMorning && !prevIsMorning) {
          dailyRep[r.date] = (r.systolic, r.diastolic);
        }
      }
    }

    final sorted = dailyRep.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sorted.isEmpty) return const SizedBox.shrink();

    final systolicSpots = sorted.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value.$1.toDouble());
    }).toList();

    final diastolicSpots = sorted.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value.$2.toDouble());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(
                '血圧 (mmHg)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.5),
                    ),
              ),
              const SizedBox(width: 12),
              _LegendDot(color: Colors.red.shade400, label: '収縮期'),
              const SizedBox(width: 8),
              _LegendDot(color: Colors.blue.shade400, label: '拡張期'),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 24, 8),
            child: LineChart(
              LineChartData(
                minY: 40,
                maxY: 200,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 40,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: cs.onSurface.withOpacity(0.06),
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 40,
                      getTitlesWidget: (val, _) => Text(
                        '${val.toInt()}',
                        style: TextStyle(
                            fontSize: 9, color: cs.onSurface.withOpacity(0.4)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: sorted.length > 14 ? 7 : 1,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= sorted.length) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime.parse(sorted[idx].key);
                        return Text(
                          DateFormat('M/d').format(date),
                          style: TextStyle(
                              fontSize: 9, color: cs.onSurface.withOpacity(0.4)),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    HorizontalRangeAnnotation(
                      y1: 90,
                      y2: 140,
                      color: Colors.green.withOpacity(0.07),
                    ),
                    HorizontalRangeAnnotation(
                      y1: 180,
                      y2: 200,
                      color: Colors.red.withOpacity(0.07),
                    ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: systolicSpots,
                    isCurved: true,
                    color: Colors.red.shade400,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 4,
                        color: spot.y >= 180 ? Colors.red.shade700 : Colors.red.shade400,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: diastolicSpots,
                    isCurved: true,
                    color: Colors.blue.shade400,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.blue.shade400,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
      ],
    );
  }
}

// ─── 体重グラフ ──────────────────────────────────────────────────

class _WeightChart extends StatelessWidget {
  final List<WeightRecord> records;

  const _WeightChart({required this.records});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Map<String, double> dailyLatest = {};
    for (final r in records) {
      dailyLatest[r.date] = r.weightKg;
    }
    final sorted = dailyLatest.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sorted.isEmpty) return const SizedBox.shrink();

    final spots = sorted.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 0.5;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            '体重 (kg)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.5),
                ),
          ),
        ),
        SizedBox(
          height: 140,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 24, 8),
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: (maxY - minY).clamp(0.5, double.infinity),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: cs.onSurface.withOpacity(0.06),
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (val, _) => Text(
                        val.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 9, color: cs.onSurface.withOpacity(0.4)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: sorted.length > 14 ? 7 : 1,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= sorted.length) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime.parse(sorted[idx].key);
                        return Text(
                          DateFormat('M/d').format(date),
                          style: TextStyle(
                              fontSize: 9,
                              color: cs.onSurface.withOpacity(0.4)),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.teal,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.teal,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.teal.withOpacity(0.06),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
