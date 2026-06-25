import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/pd_session.dart';
import '../models/daily_record.dart';
import '../models/weight_record.dart';
import '../models/blood_pressure_record.dart';
import '../models/urine_record.dart';
import '../models/bowel_record.dart';
import '../widgets/session_card.dart';
import '../widgets/session_form.dart';
import '../widgets/exit_site_form.dart';
import '../widgets/weight_form.dart';
import '../widgets/blood_pressure_form.dart';
import '../widgets/urine_form.dart';
import '../widgets/bowel_form.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);
  bool get _isToday => _dateKey == DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ja'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _goToPrevDay() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
  }

  void _goToNextDay() {
    if (!_isToday) setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final sessions = provider.sessionsForDate(_dateKey);
    final dailyRecord = provider.dailyRecordForDate(_dateKey);
    final totalUF = provider.totalUltrafiltrationForDate(_dateKey);
    final weightRecords = provider.weightRecordsForDate(_dateKey);
    final bloodPressureRecords = provider.bloodPressureRecordsForDate(_dateKey);
    final urineRecords = provider.urineRecordsForDate(_dateKey);
    final urineCount = provider.urineCountForDate(_dateKey);
    final urineTotal = provider.urineTotalForDate(_dateKey);
    final bowelRecords = provider.bowelRecordsForDate(_dateKey);
    final bowelCount = provider.bowelCountForDate(_dateKey);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _goToPrevDay,
              icon: const Icon(Icons.chevron_left),
              tooltip: '前日',
            ),
            GestureDetector(
              onTap: _pickDate,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat('M月d日（E）', 'ja').format(_selectedDate)),
                  const SizedBox(width: 4),
                  Icon(Icons.calendar_today_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ),
            IconButton(
              onPressed: _isToday ? null : _goToNextDay,
              icon: Icon(Icons.chevron_right,
                  color: _isToday
                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.2)
                      : null),
              tooltip: '翌日',
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.read<AppProvider>().logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // サマリーカード
                _SummaryCard(
                    totalUF: totalUF, sessionCount: sessions.length),
                const SizedBox(height: 12),

                // 排尿記録カード（大・フル幅）
                _UrineCard(
                  records: urineRecords,
                  count: urineCount,
                  total: urineTotal,
                  onTapNew: () => showUrineForm(context, _dateKey, null),
                  onTapRecord: (r) => showUrineForm(context, _dateKey, r),
                  onShowAll: () => _showUrineList(context, urineRecords),
                ),
                const SizedBox(height: 8),

                // お通じ記録カード（大・フル幅）
                _BowelCard(
                  records: bowelRecords,
                  count: bowelCount,
                  onTapNew: () => showBowelForm(context, _dateKey, null),
                  onTapRecord: (r) => showBowelForm(context, _dateKey, r),
                  onShowAll: () => _showBowelList(context, bowelRecords),
                ),
                const SizedBox(height: 8),

                // 出口部・体重・血圧（コンパクト3列）
                Row(
                  children: [
                    Expanded(
                      child: _CompactRecordButton(
                        icon: dailyRecord != null
                            ? (dailyRecord.isNormal
                                ? Icons.check_circle
                                : Icons.warning_rounded)
                            : Icons.radio_button_unchecked,
                        iconColor: dailyRecord != null
                            ? (dailyRecord.isNormal ? Colors.green : Colors.orange)
                            : cs.onSurface.withOpacity(0.35),
                        label: '出口部',
                        value: dailyRecord != null
                            ? (dailyRecord.isNormal ? '正常' : '要確認')
                            : '未記録',
                        hasRecord: dailyRecord != null,
                        onTap: () =>
                            showExitSiteForm(context, _dateKey, dailyRecord),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactRecordButton(
                        icon: weightRecords.isNotEmpty
                            ? Icons.monitor_weight
                            : Icons.monitor_weight_outlined,
                        iconColor: weightRecords.isNotEmpty
                            ? cs.primary
                            : cs.onSurface.withOpacity(0.35),
                        label: '体重',
                        value: weightRecords.isNotEmpty
                            ? '${weightRecords.last.weightKg} kg'
                            : '未記録',
                        hasRecord: weightRecords.isNotEmpty,
                        onTap: weightRecords.isEmpty
                            ? () => showWeightForm(context, _dateKey, null)
                            : weightRecords.length == 1
                                ? () => showWeightForm(
                                    context, _dateKey, weightRecords.first)
                                : () =>
                                    _showWeightList(context, weightRecords),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactRecordButton(
                        icon: bloodPressureRecords.isNotEmpty
                            ? Icons.favorite
                            : Icons.favorite_border,
                        iconColor: bloodPressureRecords.isNotEmpty
                            ? _bpColor(
                                bloodPressureRecords.last.systolic,
                                bloodPressureRecords.last.diastolic)
                            : cs.onSurface.withOpacity(0.35),
                        label: '血圧',
                        value: bloodPressureRecords.isNotEmpty
                            ? '${bloodPressureRecords.last.systolic}/${bloodPressureRecords.last.diastolic}'
                            : '未記録',
                        hasRecord: bloodPressureRecords.isNotEmpty,
                        onTap: bloodPressureRecords.isEmpty
                            ? () =>
                                showBloodPressureForm(context, _dateKey, null)
                            : bloodPressureRecords.length == 1
                                ? () => showBloodPressureForm(context,
                                    _dateKey, bloodPressureRecords.first)
                                : () => _showBloodPressureList(
                                    context, bloodPressureRecords),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _isToday ? '今日の記録' : 'この日の記録',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
          if (sessions.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                onAdd: () => showSessionForm(context, initialDate: _selectedDate),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index.isOdd) {
                      return _DrainDurationConnector(
                        session: sessions[index ~/ 2],
                        isLast: index ~/ 2 == sessions.length - 1,
                      );
                    }
                    final session = sessions[index ~/ 2];
                    return SessionCard(
                      session: session,
                      onEdit: () => showSessionForm(context, existing: session),
                      onDelete: () => _confirmDelete(context, session.id),
                    );
                  },
                  childCount: sessions.length * 2 - 1 +
                      (sessions.last.drainDurationMinutes != null ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSessionForm(context, initialDate: _selectedDate),
        icon: const Icon(Icons.add),
        label: const Text('セッション追加'),
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showBowelList(BuildContext context, List<BowelRecord> records) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('お通じの記録'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...records.map((r) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.wc, color: Colors.brown, size: 20),
                    title: Text(r.consistency.label),
                    subtitle: Text(
                      DateFormat('HH:mm').format(r.recordedAt) +
                          (r.note != null ? '　${r.note}' : ''),
                    ),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () {
                      Navigator.pop(context);
                      showBowelForm(context, _dateKey, r);
                    },
                  )),
              const Divider(),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  showBowelForm(context, _dateKey, null);
                },
                icon: const Icon(Icons.add),
                label: const Text('新しい記録を追加'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showUrineList(BuildContext context, List<UrineRecord> records) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('排尿量の記録'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...records.map((r) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.water_drop, color: Colors.blue, size: 20),
                    title: Text('${r.urineVolumeMl} mL'),
                    subtitle: Text(
                      DateFormat('HH:mm').format(r.recordedAt) +
                          (r.note != null ? '　${r.note}' : ''),
                    ),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () {
                      Navigator.pop(context);
                      showUrineForm(context, _dateKey, r);
                    },
                  )),
              const Divider(),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  showUrineForm(context, _dateKey, null);
                },
                icon: const Icon(Icons.add),
                label: const Text('新しい記録を追加'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showBloodPressureList(
      BuildContext context, List<BloodPressureRecord> records) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('今日の血圧記録'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...records.map((r) => ListTile(
                    dense: true,
                    leading: Icon(Icons.favorite,
                        color: _bpColor(r.systolic, r.diastolic), size: 20),
                    title: Text('${r.systolic}/${r.diastolic} mmHg'
                        '${r.pulse != null ? '　脈拍 ${r.pulse} bpm' : ''}'),
                    subtitle: Text(
                      DateFormat('HH:mm').format(r.measuredAt) +
                          (r.timing != null ? '　${r.timing}' : '') +
                          (r.note != null ? '　${r.note}' : ''),
                    ),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () {
                      Navigator.pop(context);
                      showBloodPressureForm(context, _dateKey, r);
                    },
                  )),
              const Divider(),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  showBloodPressureForm(context, _dateKey, null);
                },
                icon: const Icon(Icons.add),
                label: const Text('新しい記録を追加'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showWeightList(BuildContext context, List<WeightRecord> records) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('今日の体重記録'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...records.map((r) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.monitor_weight_outlined),
                    title: Text('${r.weightKg} kg'),
                    subtitle: Text(
                      DateFormat('HH:mm').format(r.measuredAt) +
                          (r.note != null ? '　${r.note}' : ''),
                    ),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () {
                      Navigator.pop(context);
                      showWeightForm(context, _dateKey, r);
                    },
                  )),
              const Divider(),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  showWeightForm(context, _dateKey, null);
                },
                icon: const Icon(Icons.add),
                label: const Text('新しい記録を追加'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('記録を削除'),
        content: const Text('この記録を削除しますか？元に戻せません。'),
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

// ─── サマリーカード ─────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int totalUF;
  final int sessionCount;

  const _SummaryCard({required this.totalUF, required this.sessionCount});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isNegative = totalUF < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今日の除水量合計',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withOpacity(0.6),
                          )),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${totalUF > 0 ? '+' : ''}$totalUF',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isNegative ? Colors.red : cs.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('mL',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: cs.onSurface.withOpacity(0.6))),
                    ],
                  ),
                  if (isNegative)
                    const Text(
                      '⚠ 除水量がマイナスです',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('交換回数',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.6),
                        )),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$sessionCount',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('回',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                                color: cs.onSurface.withOpacity(0.6))),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 排尿記録カード（大・フル幅）──────────────────────────────────

class _UrineCard extends StatelessWidget {
  final List<UrineRecord> records;
  final int count;
  final int total;
  final VoidCallback onTapNew;
  final ValueChanged<UrineRecord> onTapRecord;
  final VoidCallback onShowAll;

  const _UrineCard({
    required this.records,
    required this.count,
    required this.total,
    required this.onTapNew,
    required this.onTapRecord,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasRecord = records.isNotEmpty;

    VoidCallback onTap;
    if (!hasRecord) {
      onTap = onTapNew;
    } else if (records.length == 1) {
      onTap = () => onTapRecord(records.first);
    } else {
      onTap = onShowAll;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasRecord
                ? Colors.blue.withOpacity(0.5)
                : cs.outline.withOpacity(0.4),
            width: hasRecord ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: hasRecord ? Colors.blue.withOpacity(0.04) : null,
        ),
        child: Row(
          children: [
            Icon(
              hasRecord ? Icons.water_drop : Icons.water_drop_outlined,
              color: hasRecord ? Colors.blue : cs.onSurface.withOpacity(0.35),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '排尿量',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                  ),
                  const SizedBox(height: 2),
                  hasRecord
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$total',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'mL',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: cs.onSurface.withOpacity(0.6)),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '本日 $count 回',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'タップして記録する',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurface.withOpacity(0.4),
                                  ),
                        ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}

// ─── お通じ記録カード（大・フル幅）──────────────────────────────────

class _BowelCard extends StatelessWidget {
  final List<BowelRecord> records;
  final int count;
  final VoidCallback onTapNew;
  final ValueChanged<BowelRecord> onTapRecord;
  final VoidCallback onShowAll;

  const _BowelCard({
    required this.records,
    required this.count,
    required this.onTapNew,
    required this.onTapRecord,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasRecord = records.isNotEmpty;
    const color = Colors.brown;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasRecord
              ? color.withOpacity(0.4)
              : cs.outline.withOpacity(0.4),
          width: hasRecord ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: hasRecord ? color.withOpacity(0.04) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー行（アイコン + ラベル + 回数バッジ）
          Row(
            children: [
              Icon(
                Icons.wc,
                color: hasRecord ? color : cs.onSurface.withOpacity(0.35),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'お通じの記録',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.6),
                    ),
              ),
              if (hasRecord) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '本日 $count 回',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                // 直近2件の性状を推移表示
                if (records.length >= 2)
                  Text(
                    '${records[records.length - 2].consistency.label} → ${records.last.consistency.label}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                  )
                else
                  Text(
                    records.last.consistency.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // 新規記録ボタン（常時表示）
          InkWell(
            onTap: onTapNew,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.add, size: 18, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    '新しく記録する',
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 過去の記録ボタン（複数記録がある場合のみ）
          if (records.length == 1) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => onTapRecord(records.first),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        size: 16, color: cs.onSurface.withOpacity(0.5)),
                    const SizedBox(width: 6),
                    Text(
                      '記録を編集する',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (records.length > 1) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: onShowAll,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.list_outlined,
                        size: 16, color: cs.onSurface.withOpacity(0.5)),
                    const SizedBox(width: 6),
                    Text(
                      '過去の記録を見る',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── コンパクト記録ボタン（出口部・体重・血圧用）──────────────────

class _CompactRecordButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool hasRecord;
  final VoidCallback onTap;

  const _CompactRecordButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.hasRecord,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasRecord
                ? iconColor.withOpacity(0.4)
                : cs.outline.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.55),
                    fontSize: 10,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasRecord ? FontWeight.w600 : FontWeight.normal,
                color: hasRecord
                    ? cs.onSurface
                    : cs.onSurface.withOpacity(0.4),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

Color _bpColor(int systolic, int diastolic) {
  if (systolic >= 180 || diastolic >= 110) return Colors.red;
  if (systolic >= 160 || diastolic >= 100 || systolic < 90) return Colors.orange;
  return Colors.green;
}

// ─── 廃液時間コネクター ───────────────────────────────────────────

class _DrainDurationConnector extends StatelessWidget {
  final PDSession session;
  final bool isLast;

  const _DrainDurationConnector(
      {required this.session, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasValue = session.drainDurationMinutes != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 24),
          Container(
            width: 2,
            height: 32,
            color: hasValue
                ? cs.primary.withOpacity(0.3)
                : cs.onSurface.withOpacity(0.1),
          ),
          const SizedBox(width: 12),
          Text(
            hasValue
                ? '廃液時間: ${session.drainDurationLabel}'
                : '廃液時間: ── (次の記録後に表示)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: hasValue
                      ? cs.primary
                      : cs.onSurface.withOpacity(0.35),
                  fontStyle:
                      hasValue ? FontStyle.normal : FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── セッションなし空状態 ─────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.water_drop_outlined,
              size: 64, color: cs.onSurface.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('今日の記録はまだありません',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: cs.onSurface.withOpacity(0.4),
                  )),
          const SizedBox(height: 8),
          Text('最初のセッションを追加しましょう',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.3),
                  )),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('セッションを追加'),
          ),
        ],
      ),
    );
  }
}
