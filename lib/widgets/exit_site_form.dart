import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/daily_record.dart';
import '../providers/app_provider.dart';

Future<void> showExitSiteForm(
    BuildContext context, String date, DailyRecord? existing) async {
  await showDialog(
    context: context,
    builder: (_) => ExitSiteDialog(date: date, existing: existing),
  );
}

class ExitSiteDialog extends StatefulWidget {
  final String date;
  final DailyRecord? existing;

  const ExitSiteDialog({super.key, required this.date, this.existing});

  @override
  State<ExitSiteDialog> createState() => _ExitSiteDialogState();
}

class _ExitSiteDialogState extends State<ExitSiteDialog> {
  bool _isNormal = true;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _isNormal = widget.existing!.isNormal;
      if (!_isNormal) {
        _noteController.text = widget.existing!.exitSiteCondition;
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('出口部の状態'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 正常ボタン
          GestureDetector(
            onTap: () => setState(() => _isNormal = true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _isNormal
                    ? Colors.green.withOpacity(0.1)
                    : Colors.transparent,
                border: Border.all(
                  color: _isNormal ? Colors.green : cs.outline.withOpacity(0.4),
                  width: _isNormal ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle,
                        color: _isNormal
                            ? Colors.green
                            : cs.onSurface.withOpacity(0.3)),
                    const SizedBox(width: 8),
                    Text(
                      '正常',
                      style: TextStyle(
                        fontWeight: _isNormal ? FontWeight.bold : null,
                        color: _isNormal ? Colors.green : cs.onSurface,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 異常あり
          GestureDetector(
            onTap: () => setState(() => _isNormal = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: !_isNormal
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.transparent,
                border: Border.all(
                  color: !_isNormal
                      ? Colors.orange
                      : cs.outline.withOpacity(0.4),
                  width: !_isNormal ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_rounded,
                        color: !_isNormal
                            ? Colors.orange
                            : cs.onSurface.withOpacity(0.3)),
                    const SizedBox(width: 8),
                    Text(
                      '異常あり（詳細を記入）',
                      style: TextStyle(
                        fontWeight: !_isNormal ? FontWeight.bold : null,
                        color: !_isNormal ? Colors.orange : cs.onSurface,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!_isNormal) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '状態を入力してください（例: 出口部が赤い）',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 2,
            ),
          ],
        ],
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

  void _save() {
    final condition =
        _isNormal ? '正常' : _noteController.text.trim();
    if (!_isNormal && condition.isEmpty) return;

    context.read<AppProvider>().saveExitSite(DailyRecord(
          date: widget.date,
          exitSiteCondition: condition,
          recordedAt: DateTime.now(),
        ));
    Navigator.pop(context);
  }
}
