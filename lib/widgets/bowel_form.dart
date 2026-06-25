import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/bowel_record.dart';
import '../providers/app_provider.dart';

Future<void> showBowelForm(
    BuildContext context, String date, BowelRecord? existing) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BowelFormSheet(date: date, existing: existing),
  );
}

class BowelFormSheet extends StatefulWidget {
  final String date;
  final BowelRecord? existing;

  const BowelFormSheet({super.key, required this.date, this.existing});

  @override
  State<BowelFormSheet> createState() => _BowelFormSheetState();
}

class _BowelFormSheetState extends State<BowelFormSheet> {
  BowelConsistency? _consistency;
  late DateTime _recordedAt;
  final _noteCtrl = TextEditingController();
  bool _showNote = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _recordedAt = widget.existing?.recordedAt ?? DateTime.now();
    _consistency = widget.existing?.consistency;
    _noteCtrl.text = widget.existing?.note ?? '';
    if (widget.existing?.note != null && widget.existing!.note!.isNotEmpty) {
      _showNote = true;
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
    );
    if (time != null && mounted) {
      setState(() {
        _recordedAt = DateTime(
          _recordedAt.year,
          _recordedAt.month,
          _recordedAt.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  void _save() {
    if (_consistency == null) {
      setState(() => _showError = true);
      return;
    }
    final provider = context.read<AppProvider>();
    final record = BowelRecord(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      recordedAt: _recordedAt,
      date: DateFormat('yyyy-MM-dd').format(_recordedAt),
      consistency: _consistency!,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    if (widget.existing != null) {
      provider.updateBowelRecord(record);
    } else {
      provider.addBowelRecord(record);
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('記録しました ✓'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('記録を削除'),
        content: const Text('このお通じの記録を削除しますか？'),
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
      context.read<AppProvider>().deleteBowelRecord(widget.existing!.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEditing = widget.existing != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ドラッグハンドル
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // タイトル
          Text(
            isEditing ? 'お通じを編集' : 'お通じを記録',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // 時刻行（行全体をタップ可能）
          InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border:
                    Border.all(color: cs.outline.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    '時刻: ${DateFormat('HH:mm').format(_recordedAt)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text('変更',
                      style:
                          TextStyle(fontSize: 12, color: cs.primary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 性状ラベル + エラー表示
          Row(
            children: [
              Text(
                '性状を選んでください',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              if (_showError) ...[
                const SizedBox(width: 8),
                Text(
                  '（必須）',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // 性状選択（縦並びラジオボタン風）
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _showError
                    ? Colors.red.withOpacity(0.6)
                    : cs.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: BowelConsistency.values.asMap().entries.map((entry) {
                final idx = entry.key;
                final c = entry.value;
                final isSelected = _consistency == c;
                final isLast = idx == BowelConsistency.values.length - 1;

                return InkWell(
                  onTap: () => setState(() {
                    _consistency = c;
                    _showError = false;
                  }),
                  borderRadius: BorderRadius.vertical(
                    top: idx == 0 ? const Radius.circular(10) : Radius.zero,
                    bottom: isLast ? const Radius.circular(10) : Radius.zero,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primaryContainer.withOpacity(0.5)
                          : null,
                      border: isLast
                          ? null
                          : Border(
                              bottom: BorderSide(
                                color: cs.outline.withOpacity(0.15),
                              ),
                            ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: isSelected
                              ? cs.primary
                              : cs.onSurface.withOpacity(0.35),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          c.label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? cs.primary
                                : cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // メモ（折りたたみ）
          if (_showNote)
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'メモ（任意）',
                hintText: '例: 腹痛を伴った',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            )
          else
            GestureDetector(
              onTap: () => setState(() => _showNote = true),
              child: Row(
                children: [
                  Icon(Icons.add, size: 16, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(
                    'メモを追加',
                    style: TextStyle(fontSize: 13, color: cs.primary),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // アクションボタン
          Row(
            children: [
              if (isEditing)
                TextButton(
                  onPressed: _confirmDelete,
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('削除'),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _save,
                child: const Text('記録する'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
