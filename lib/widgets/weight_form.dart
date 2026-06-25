import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/weight_record.dart';
import '../providers/app_provider.dart';

Future<void> showWeightForm(
    BuildContext context, String date, WeightRecord? existing) async {
  await showDialog<void>(
    context: context,
    builder: (_) => WeightDialog(date: date, existing: existing),
  );
}

class WeightDialog extends StatefulWidget {
  final String date;
  final WeightRecord? existing;

  const WeightDialog({super.key, required this.date, this.existing});

  @override
  State<WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<WeightDialog> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _measuredAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _measuredAt = widget.existing?.measuredAt ?? DateTime.now();
    _weightCtrl = TextEditingController(
      text: widget.existing != null ? '${widget.existing!.weightKg}' : '',
    );
    _noteCtrl = TextEditingController(text: widget.existing?.note ?? '');
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
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
      _measuredAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _save() {
    final text = _weightCtrl.text.trim();
    final kg = double.tryParse(text);
    if (kg == null || kg < 20.0 || kg > 200.0) {
      setState(() => _error = '20〜200 の範囲で入力してください');
      return;
    }

    final provider = context.read<AppProvider>();
    final record = WeightRecord(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      weightKg: kg,
      measuredAt: _measuredAt,
      date: DateFormat('yyyy-MM-dd').format(_measuredAt),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    if (widget.existing != null) {
      provider.updateWeightRecord(record);
    } else {
      provider.addWeightRecord(record);
    }
    Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('記録を削除'),
        content: const Text('この体重記録を削除しますか？'),
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
      context.read<AppProvider>().deleteWeightRecord(widget.existing!.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(isEditing ? '体重を編集' : '体重を記録'),
      content: Column(
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
                  Icon(Icons.calendar_today_outlined, size: 18, color: cs.primary),
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
          // 体重入力
          TextField(
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: '体重',
              suffixText: 'kg',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          // メモ入力
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'メモ（省略可）',
              hintText: '例: 起床時、透析後',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        if (isEditing)
          TextButton(
            onPressed: _confirmDelete,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
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
