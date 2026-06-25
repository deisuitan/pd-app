import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/pd_session.dart';
import '../providers/app_provider.dart';
import '../services/storage_service.dart';

Future<void> showSessionForm(BuildContext context,
    {PDSession? existing, DateTime? initialDate}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SessionFormSheet(existing: existing, initialDate: initialDate),
  );
}

class SessionFormSheet extends StatefulWidget {
  final PDSession? existing;
  final DateTime? initialDate;
  const SessionFormSheet({super.key, this.existing, this.initialDate});

  @override
  State<SessionFormSheet> createState() => _SessionFormSheetState();
}

class _SessionFormSheetState extends State<SessionFormSheet> {
  late DateTime _fillStartTime;
  late DateTime _drainStartTime;
  late String _dialysateType;
  int? _drainVolume;
  late DrainAppearance _drainAppearance;
  late List<String> _photoStoragePaths;
  bool _isUploadingPhoto = false;
  final _noteController = TextEditingController();
  final _drainVolumeController = TextEditingController();
  final _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final s = widget.existing;
    // 新規追加時は initialDate の日付 + 現在時刻をデフォルトにする
    final base = widget.initialDate == null
        ? now
        : DateTime(widget.initialDate!.year, widget.initialDate!.month,
            widget.initialDate!.day, now.hour, now.minute);
    _fillStartTime = s?.fillStartTime ?? base;
    var loadedDrain = s?.drainStartTime ?? base;
    // 廃液開始が貯留開始より前 = 日付をまたぐ記録ミス → 翌日に自動補正
    if (loadedDrain.isBefore(_fillStartTime)) {
      loadedDrain = loadedDrain.add(const Duration(days: 1));
    }
    _drainStartTime = loadedDrain;
    _dialysateType = s?.dialysateType ?? kDialysateTypes.first;
    _drainVolume = s?.drainVolume;
    _drainAppearance = s?.drainAppearance ?? DrainAppearance.normal;
    _photoStoragePaths = List<String>.from(s?.photoStoragePaths ?? []);
    _noteController.text = s?.appearanceNote ?? '';
    _drainVolumeController.text = _drainVolume?.toString() ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    _drainVolumeController.dispose();
    super.dispose();
  }

  int? get _ultrafiltration =>
      _drainVolume == null ? null : _drainVolume! - 2000;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 1.0,
      minChildSize: 0.6,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // ハンドル
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // タイトル
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  isEdit ? 'セッションを編集' : 'セッションを追加',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
          ),
          const Divider(height: 1),
          // フォーム
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('時間'),
                  const SizedBox(height: 8),
                  // ① 貯留開始時刻
                  _TimeField(
                    label: '① 貯留開始時刻',
                    time: _fillStartTime,
                    onNow: () =>
                        setState(() => _fillStartTime = DateTime.now()),
                    onAdjust: (minutes) => setState(() => _fillStartTime =
                        _fillStartTime.add(Duration(minutes: minutes))),
                    onPick: (t) => setState(() => _fillStartTime = t),
                  ),
                  const SizedBox(height: 12),
                  // ② 廃液開始時刻
                  _TimeField(
                    label: '② 廃液開始時刻',
                    time: _drainStartTime,
                    onNow: () =>
                        setState(() => _drainStartTime = DateTime.now()),
                    onAdjust: (minutes) => setState(() => _drainStartTime =
                        _drainStartTime
                            .add(Duration(minutes: minutes))),
                    onPick: (t) {
                      // 選択した時刻が貯留開始より前 = 日付をまたいでいる → 1日加算
                      final adjusted = t.isBefore(_fillStartTime)
                          ? t.add(const Duration(days: 1))
                          : t;
                      setState(() => _drainStartTime = adjusted);
                    },
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('透析液の種類'),
                  const SizedBox(height: 8),
                  // ③ 透析液種類
                  Row(
                    children: kDialysateTypes.map((type) {
                      final selected = _dialysateType == type;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _BigChoiceButton(
                            label: type,
                            selected: selected,
                            onTap: () =>
                                setState(() => _dialysateType = type),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('廃液量'),
                  const SizedBox(height: 8),
                  // ④ 廃液量
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          controller: _drainVolumeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                            suffixText: 'mL',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          onChanged: (v) {
                            if (v.isEmpty) {
                              setState(() => _drainVolume = null);
                            } else {
                              final n = int.tryParse(v);
                              if (n != null && n >= 500 && n <= 3000) {
                                setState(() => _drainVolume = n);
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // ⑤⑥ 注液量・除水量（読み取り専用）
                      Expanded(
                        child: Row(
                          children: [
                            _ReadonlyStat(
                                label: '⑤ 注液量',
                                value: '2000 mL'),
                            const SizedBox(width: 12),
                            _ReadonlyStat(
                              label: '⑥ 除水量',
                              value: _ultrafiltration == null
                                  ? '──'
                                  : '${_ultrafiltration! >= 0 ? '+' : ''}${_ultrafiltration!} mL',
                              color: _ultrafiltration == null
                                  ? null
                                  : (_ultrafiltration! < 0
                                      ? Colors.red
                                      : Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_ultrafiltration != null && _ultrafiltration! < 0) ...[
                    const SizedBox(height: 8),
                    _WarningBanner(
                        '除水量がマイナスです。廃液量をご確認ください。'),
                  ],
                  const SizedBox(height: 20),
                  _sectionLabel('廃液の状態'),
                  const SizedBox(height: 8),
                  // ⑧ 廃液の状態
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: DrainAppearance.values.map((a) {
                      final selected = _drainAppearance == a;
                      return _BigChoiceButton(
                        label: a.label,
                        selected: selected,
                        onTap: () =>
                            setState(() => _drainAppearance = a),
                        selectedColor:
                            a == DrainAppearance.normal ? null : Colors.orange,
                      );
                    }).toList(),
                  ),
                  if (_drainAppearance != DrainAppearance.normal) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: 'メモ（状態の詳細）',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    // 写真アップロード
                    OutlinedButton.icon(
                      onPressed: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                      icon: _isUploadingPhoto
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_camera_outlined),
                      label: Text(_isUploadingPhoto
                          ? 'アップロード中...'
                          : 'カメラで撮影 / ギャラリーから選ぶ'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    if (_photoStoragePaths.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _PhotoCountBadge(count: _photoStoragePaths.length),
                    ],
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // 保存ボタン（常に下部に固定）
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed: _save,
                child: Text(isEdit ? '変更を保存' : 'セッションを保存'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
      );

  void _save() {
    final provider = context.read<AppProvider>();
    final date = DateFormat('yyyy-MM-dd').format(_fillStartTime);
    final noteText = _noteController.text.trim();
    final note = (_drainAppearance != DrainAppearance.normal && noteText.isNotEmpty)
        ? noteText
        : null;

    // 保存時点でテキストフィールドの値を直接読み取る（onChangedが最終入力を
    // 取り逃した場合（ペースト・予測変換など）でも正しい値が保存されるよう保険をかける）
    final rawText = _drainVolumeController.text.trim();
    final drainVolumeToSave = rawText.isEmpty ? null : (int.tryParse(rawText) ?? _drainVolume);

    if (widget.existing != null) {
      provider.updateSession(PDSession(
        id: widget.existing!.id,
        date: date,
        fillStartTime: _fillStartTime,
        drainStartTime: _drainStartTime,
        dialysateType: _dialysateType,
        drainVolume: drainVolumeToSave,
        drainDurationMinutes: widget.existing!.drainDurationMinutes,
        drainAppearance: _drainAppearance,
        appearanceNote: note,
        photoStoragePaths: _photoStoragePaths,
      ));
    } else {
      provider.addSession(PDSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: date,
        fillStartTime: _fillStartTime,
        drainStartTime: _drainStartTime,
        dialysateType: _dialysateType,
        drainVolume: drainVolumeToSave,
        drainAppearance: _drainAppearance,
        appearanceNote: note,
        photoStoragePaths: _photoStoragePaths,
      ));
    }
    Navigator.pop(context);
  }

  Future<void> _pickAndUploadPhoto() async {
    final uid = context.read<AppProvider>().userId;
    if (uid == null) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final bytes = await file.readAsBytes();
      final path = await _storageService.uploadPhoto(bytes, uid);
      setState(() => _photoStoragePaths.add(path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('写真のアップロードに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final DateTime time;
  final VoidCallback onNow;
  final void Function(int minutes) onAdjust;
  final void Function(DateTime) onPick;

  const _TimeField({
    required this.label,
    required this.time,
    required this.onNow,
    required this.onAdjust,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final timeStr = DateFormat('HH:mm').format(time);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurface.withOpacity(0.6))),
        const SizedBox(height: 6),
        Row(
          children: [
            // 今すぐボタン
            Expanded(
              child: FilledButton.tonal(
                onPressed: onNow,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                child: Text(
                  '今すぐ記録  $timeStr',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // -5分
            _AdjustButton(
                label: '-5分',
                onTap: () => onAdjust(-5)),
            const SizedBox(width: 4),
            // +5分
            _AdjustButton(
                label: '+5分',
                onTap: () => onAdjust(5)),
            const SizedBox(width: 4),
            // 時刻ピッカー
            IconButton(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(time),
                );
                if (picked != null) {
                  onPick(DateTime(time.year, time.month, time.day,
                      picked.hour, picked.minute));
                }
              },
              icon: const Icon(Icons.access_time),
              tooltip: '時刻を選ぶ',
            ),
          ],
        ),
      ],
    );
  }
}

class _AdjustButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AdjustButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _BigChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const _BigChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selectedColor ?? cs.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.transparent,
          border: Border.all(
            color: selected ? color : cs.outline.withOpacity(0.4),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? color : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadonlyStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _ReadonlyStat(
      {required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10, color: cs.onSurface.withOpacity(0.5))),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color ?? cs.onSurface,
            )),
      ],
    );
  }
}

class _PhotoCountBadge extends StatelessWidget {
  final int count;
  const _PhotoCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline,
            size: 16, color: Colors.green),
        const SizedBox(width: 6),
        Text(
          '写真 $count 枚添付済み',
          style: const TextStyle(fontSize: 13, color: Colors.green),
        ),
      ],
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;
  const _WarningBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: Colors.red),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message,
                style:
                    const TextStyle(fontSize: 12, color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
