import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/blood_pressure_record.dart';
import '../providers/app_provider.dart';

const _timingOptions = ['起床時', '透析前', '透析後', '就寝前', 'その他'];

Future<void> showBloodPressureForm(
    BuildContext context, String date, BloodPressureRecord? existing) async {
  await showDialog<void>(
    context: context,
    builder: (_) => BloodPressureDialog(date: date, existing: existing),
  );
}

class BloodPressureDialog extends StatefulWidget {
  final String date;
  final BloodPressureRecord? existing;

  const BloodPressureDialog({super.key, required this.date, this.existing});

  @override
  State<BloodPressureDialog> createState() => _BloodPressureDialogState();
}

class _BloodPressureDialogState extends State<BloodPressureDialog> {
  late final TextEditingController _systolicCtrl;
  late final TextEditingController _diastolicCtrl;
  late final TextEditingController _pulseCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _measuredAt;
  String? _timing;
  String? _error;

  @override
  void initState() {
    super.initState();
    _measuredAt = widget.existing?.measuredAt ?? DateTime.now();
    _timing = widget.existing?.timing;
    _systolicCtrl = TextEditingController(
      text: widget.existing != null ? '${widget.existing!.systolic}' : '',
    );
    _diastolicCtrl = TextEditingController(
      text: widget.existing != null ? '${widget.existing!.diastolic}' : '',
    );
    _pulseCtrl = TextEditingController(
      text: widget.existing?.pulse != null ? '${widget.existing!.pulse}' : '',
    );
    _noteCtrl = TextEditingController(text: widget.existing?.note ?? '');
  }

  @override
  void dispose() {
    _systolicCtrl.dispose();
    _diastolicCtrl.dispose();
    _pulseCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _measuredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('ja'),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_measuredAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _measuredAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _save() {
    final sysText = _systolicCtrl.text.trim();
    final diaText = _diastolicCtrl.text.trim();
    final pulseText = _pulseCtrl.text.trim();

    final systolic = int.tryParse(sysText);
    final diastolic = int.tryParse(diaText);
    final pulse = pulseText.isEmpty ? null : int.tryParse(pulseText);

    if (systolic == null || systolic < 60 || systolic > 250) {
      setState(() => _error = '収縮期は 60〜250 の範囲で入力してください');
      return;
    }
    if (diastolic == null || diastolic < 40 || diastolic > 150) {
      setState(() => _error = '拡張期は 40〜150 の範囲で入力してください');
      return;
    }
    if (diastolic >= systolic) {
      setState(() => _error = '収縮期（上）は拡張期（下）より大きい値を入力してください');
      return;
    }
    if (pulse != null && (pulse < 30 || pulse > 200)) {
      setState(() => _error = '脈拍は 30〜200 の範囲で入力してください');
      return;
    }

    final provider = context.read<AppProvider>();
    final record = BloodPressureRecord(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
      timing: _timing,
      measuredAt: _measuredAt,
      date: DateFormat('yyyy-MM-dd').format(_measuredAt),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    if (widget.existing != null) {
      provider.updateBloodPressureRecord(record);
    } else {
      provider.addBloodPressureRecord(record);
    }
    Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('記録を削除'),
        content: const Text('この血圧記録を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<AppProvider>().deleteBloodPressureRecord(widget.existing!.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(isEditing ? '血圧を編集' : '血圧を記録'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日時ピッカー
            InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outline.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('M月d日 HH:mm').format(_measuredAt),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Text('変更',
                        style: TextStyle(fontSize: 12, color: cs.primary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 収縮期 / 拡張期 横並び
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _systolicCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '収縮期（上）',
                      suffixText: 'mmHg',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  child: Text('/',
                      style: TextStyle(
                          fontSize: 22, color: cs.onSurface.withOpacity(0.5))),
                ),
                Expanded(
                  child: TextField(
                    controller: _diastolicCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '拡張期（下）',
                      suffixText: 'mmHg',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!,
                  style: TextStyle(fontSize: 12, color: cs.error)),
            ],
            const SizedBox(height: 12),
            // 脈拍
            TextField(
              controller: _pulseCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '脈拍（省略可）',
                suffixText: 'bpm',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // 測定タイミング
            DropdownButtonFormField<String>(
              value: _timing,
              decoration: const InputDecoration(
                labelText: '測定タイミング（省略可）',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('─ 選択しない')),
                ..._timingOptions.map((t) =>
                    DropdownMenuItem(value: t, child: Text(t))),
              ],
              onChanged: (v) => setState(() => _timing = v),
            ),
            const SizedBox(height: 12),
            // メモ
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'メモ（省略可）',
                hintText: '例: 安静時',
                border: OutlineInputBorder(),
              ),
            ),
            // 削除ボタン（編集時のみ、content末尾に小さく）
            if (isEditing) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('この記録を削除'),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurface.withOpacity(0.45),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
