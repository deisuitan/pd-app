import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/urine_record.dart';
import '../providers/app_provider.dart';

Future<void> showUrineForm(
    BuildContext context, String date, UrineRecord? existing) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => UrineFormSheet(date: date, existing: existing),
  );
}

class UrineFormSheet extends StatefulWidget {
  final String date;
  final UrineRecord? existing;

  const UrineFormSheet({super.key, required this.date, this.existing});

  @override
  State<UrineFormSheet> createState() => _UrineFormSheetState();
}

class _UrineFormSheetState extends State<UrineFormSheet> {
  String _digits = '';
  late DateTime _recordedAt;
  final _noteCtrl = TextEditingController();
  bool _showNote = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recordedAt = widget.existing?.recordedAt ?? DateTime.now();
    if (widget.existing != null) {
      _digits = '${widget.existing!.urineVolumeMl}';
    }
    _noteCtrl.text = widget.existing?.note ?? '';
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  int? get _currentValue => _digits.isEmpty ? null : int.tryParse(_digits);

  void _onKey(String digit) {
    if (_error != null) setState(() => _error = null);
    final next = _digits + digit;
    final val = int.tryParse(next);
    if (val != null && val <= 3000 && next.length <= 4) {
      setState(() => _digits = next);
    }
  }

  void _onBackspace() {
    if (_digits.isNotEmpty) {
      setState(() {
        _digits = _digits.substring(0, _digits.length - 1);
        _error = null;
      });
    }
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
    if (_digits.isEmpty) {
      setState(() => _error = '尿量を入力してください');
      return;
    }
    final vol = _currentValue!;
    final provider = context.read<AppProvider>();
    final record = UrineRecord(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      urineVolumeMl: vol,
      recordedAt: _recordedAt,
      date: DateFormat('yyyy-MM-dd').format(_recordedAt),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    if (widget.existing != null) {
      provider.updateUrineRecord(record);
    } else {
      provider.addUrineRecord(record);
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
        content: const Text('この排尿記録を削除しますか？'),
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
      context.read<AppProvider>().deleteUrineRecord(widget.existing!.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEditing = widget.existing != null;
    final hasValue = _digits.isNotEmpty;

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
            isEditing ? '排尿量を編集' : '排尿量を記録',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // 数値表示エリア
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      hasValue ? _digits : '──',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        color: hasValue
                            ? cs.primary
                            : cs.onSurface.withOpacity(0.25),
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'mL',
                      style: TextStyle(
                        fontSize: 20,
                        color: cs.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _error!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // テンキー
          _Numpad(onKey: _onKey, onBackspace: _onBackspace),
          const SizedBox(height: 10),

          // 時刻行
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
          const SizedBox(height: 8),

          // メモ（折りたたみ）
          if (_showNote)
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'メモ（色・濁りなど）',
                hintText: '例: 少し濁っていた',
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
          const SizedBox(height: 12),

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

class _Numpad extends StatelessWidget {
  final void Function(String) onKey;
  final VoidCallback onBackspace;

  const _Numpad({required this.onKey, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: row.asMap().entries.map((e) {
                final idx = e.key;
                final key = e.value;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: idx > 0 ? 6 : 0),
                    child: key.isEmpty
                        ? const SizedBox.shrink()
                        : key == '⌫'
                            ? OutlinedButton(
                                onPressed: onBackspace,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  foregroundColor: cs.onSurface,
                                ),
                                child: const Icon(
                                    Icons.backspace_outlined,
                                    size: 20),
                              )
                            : OutlinedButton(
                                onPressed: () => onKey(key),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  foregroundColor: cs.onSurface,
                                ),
                                child: Text(
                                  key,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
