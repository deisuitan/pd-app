import 'package:flutter/material.dart';
import '../models/pd_session.dart';

class SessionCard extends StatelessWidget {
  final PDSession session;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SessionCard({
    super.key,
    required this.session,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uf = session.ultrafiltration; // int? — 廃液量未入力なら null
    final isNegativeUF = (uf ?? 0) < 0;
    final ufColor = isNegativeUF ? Colors.red : Colors.green;
    final isAbnormal =
        session.drainAppearance != DrainAppearance.normal;

    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー行（時刻と液種）
              Row(
                children: [
                  Icon(Icons.schedule, size: 16,
                      color: cs.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    session.drainVolume != null
                        ? '${session.fillTimeLabel} 貯留 → ${session.drainTimeLabel} 廃液開始'
                        : '${session.fillTimeLabel} 貯留',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: cs.onSurface.withOpacity(0.3),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (session.drainVolume != null) ...[
                const SizedBox(height: 2),
                // 貯留時間（廃液開始 - 貯留開始）
                Row(
                  children: [
                    Icon(Icons.hourglass_bottom_rounded,
                        size: 13,
                        color: cs.onSurface.withOpacity(0.38)),
                    const SizedBox(width: 3),
                    Text(
                      '貯留時間: ${session.dwellDurationLabel}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withOpacity(0.5),
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              // 液種チップ
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  session.dialysateType,
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.primary,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 10),
              // 量の数値行
              Row(
                children: [
                  _Stat(
                      label: '廃液量',
                      value: session.drainVolume != null
                          ? '${session.drainVolume}'
                          : '──',
                      unit: 'mL'),
                  const SizedBox(width: 16),
                  _Stat(label: '注液量',
                      value: '${session.fillVolume}',
                      unit: 'mL'),
                  const SizedBox(width: 16),
                  _Stat(
                    label: '除水量',
                    value: uf == null ? '──' : '${uf >= 0 ? '+' : ''}$uf',
                    unit: 'mL',
                    valueColor: uf == null ? null : ufColor,
                    isBold: true,
                  ),
                ],
              ),
              // 廃液状態
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isAbnormal ? Colors.orange : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '廃液: ${session.drainAppearance.label}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isAbnormal
                              ? Colors.orange
                              : cs.onSurface.withOpacity(0.6),
                          fontWeight: isAbnormal
                              ? FontWeight.w600
                              : null,
                        ),
                  ),
                  if (session.appearanceNote != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '— ${session.appearanceNote}',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color:
                                      cs.onSurface.withOpacity(0.5),
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (session.photoStoragePaths.isNotEmpty) ...[
                    const Spacer(),
                    Icon(Icons.photo_camera_outlined,
                        size: 14,
                        color: cs.onSurface.withOpacity(0.4)),
                    const SizedBox(width: 2),
                    Text(
                      '${session.photoStoragePaths.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withOpacity(0.4),
                          ),
                    ),
                  ],
                ],
              ),
              if (isNegativeUF) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        '除水量がマイナスです。廃液量をご確認ください。',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color? valueColor;
  final bool isBold;

  const _Stat({
    required this.label,
    required this.value,
    required this.unit,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.5),
                  fontSize: 10,
                )),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: isBold ? 18 : 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: valueColor ?? cs.onSurface,
              ),
            ),
            const SizedBox(width: 2),
            Text(unit,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.5),
                      fontSize: 10,
                    )),
          ],
        ),
      ],
    );
  }
}
