import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _backup = BackupService();
  bool _isBusy = false;

  // ─── エラー表示（患者向けメッセージに変換）─────────────────
  String _friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('sign_in') || msg.contains('developer_error')) {
      return 'Googleアカウントへのアクセスに失敗しました。\nしばらく経ってから再度お試しください。';
    }
    if (msg.contains('timeout') || msg.contains('deadline')) {
      return 'インターネット接続がタイムアウトしました。\nWi-Fiに接続して、もう一度試してください。';
    }
    if (msg.contains('invalid') || msg.contains('corrupt')) {
      return 'ファイル形式が正しくありません。\nこのアプリが生成したバックアップファイルを使用してください。';
    }
    return '問題が発生しました。しばらく経ってから試してください。';
  }

  void _showError(String title, dynamic e) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red),
        title: Text(title),
        content: Text(_friendlyError(e)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  // ─── バックアップ（ZIPダウンロード）───────────────────────
  Future<void> _downloadZip() async {
    final provider = context.read<AppProvider>();
    setState(() => _isBusy = true);
    try {
      _backup.downloadZip(provider.sessions, provider.dailyRecords, provider.weightRecords,
          provider.bloodPressureRecords, provider.urineRecords, provider.bowelRecords);
      if (mounted) {
        _snack('バックアップを保存しました', success: true);
      }
    } catch (e) {
      if (mounted) _showError('バックアップの保存に失敗しました', e);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ─── 復元（ZIPアップロード）──────────────────────────────
  Future<void> _uploadZip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('バックアップから復元'),
        content: const Text(
          'バックアップファイルの治療記録を読み込みます。\n\n'
          '• 同じ日時の記録は新しいデータに置き換わります\n'
          '• バックアップにない記録はそのまま残ります\n\n'
          '心配な場合はキャンセルしてください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('復元する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final (sessions, dailyRecords, weightRecords, bloodPressureRecords, urineRecords, bowelRecords) =
          await _backup.pickAndReadZip();
      if (!mounted) return;
      await context
          .read<AppProvider>()
          .restoreBackup(sessions, dailyRecords, weightRecords, bloodPressureRecords, urineRecords, bowelRecords);
      if (mounted) {
        _snack(
          'セッション ${sessions.length} 件・日次記録 ${dailyRecords.length} 件'
          '・体重記録 ${weightRecords.length} 件'
          '・血圧記録 ${bloodPressureRecords.length} 件'
          '・排尿記録 ${urineRecords.length} 件'
          '・お通じ記録 ${bowelRecords.length} 件を復元しました',
          success: true,
        );
      }
    } catch (e) {
      if (mounted) _showError('復元に失敗しました', e);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ─── 血圧CSVエクスポート ──────────────────────────────────
  Future<void> _exportBloodPressureCsv() async {
    final provider = context.read<AppProvider>();
    setState(() => _isBusy = true);
    try {
      _backup.downloadBloodPressureCsv(provider.bloodPressureRecords);
      if (mounted) _snack('血圧CSVをダウンロードしました', success: true);
    } catch (e) {
      if (mounted) _showError('血圧CSVエクスポートに失敗しました', e);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ─── 体重CSVエクスポート ──────────────────────────────────
  Future<void> _exportWeightCsv() async {
    final provider = context.read<AppProvider>();
    setState(() => _isBusy = true);
    try {
      _backup.downloadWeightCsv(provider.weightRecords);
      if (mounted) _snack('体重CSVをダウンロードしました', success: true);
    } catch (e) {
      if (mounted) _showError('体重CSVエクスポートに失敗しました', e);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ─── CSVエクスポート ───────────────────────────────────────
  Future<void> _exportCsv() async {
    final provider = context.read<AppProvider>();
    setState(() => _isBusy = true);
    try {
      _backup.downloadCsv(provider.sessions);
      if (mounted) _snack('CSVをダウンロードしました', success: true);
    } catch (e) {
      if (mounted) _showError('CSVエクスポートに失敗しました', e);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: success ? Colors.green.shade700 : null,
    ));
  }

  // ─── Drive バックアップ ───────────────────────────────────
  Future<void> _enableDrive() async {
    // 事前に説明ダイアログを出す
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.cloud_upload_outlined, color: Colors.blue),
        title: const Text('Googleドライブと連携'),
        content: const Text(
          'Googleアカウントと連携すると、アプリを開くたびに自動で治療記録をバックアップします。\n\n'
          '• 1週間分の履歴を保持します\n'
          '• 次の画面でGoogleアカウントの許可が必要です',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('次へ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final ok = await context.read<AppProvider>().enableDriveBackup();
      if (mounted) {
        _snack(ok ? 'Googleドライブと連携しました' : '連携がキャンセルされました',
            success: ok);
      }
    } catch (e) {
      if (mounted) _showError('Googleドライブとの連携に失敗しました', e);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _disableDrive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Drive連携を無効にする'),
        content: const Text('自動バックアップを停止しますか？\nドライブ上のファイルは削除されません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          OutlinedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('無効にする')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AppProvider>().disableDriveBackup();
    if (mounted) _snack('Drive連携を無効にしました');
  }

  Future<void> _manualDriveBackup() async {
    setState(() => _isBusy = true);
    try {
      await context.read<AppProvider>().manualDriveBackup();
      if (mounted) _snack('Googleドライブにバックアップしました', success: true);
    } catch (e) {
      if (mounted) _showError('バックアップに失敗しました', e);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ─── UI ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionLabel('Googleドライブ自動バックアップ'),
              Consumer<AppProvider>(
                builder: (_, provider, __) =>
                    _DriveBackupCard(
                  enabled: provider.driveBackupEnabled,
                  lastBackupDate: provider.lastDriveBackupDate,
                  isRunning: provider.isDriveBackupRunning || _isBusy,
                  onEnable: _isBusy ? null : _enableDrive,
                  onDisable: _isBusy ? null : _disableDrive,
                  onBackupNow: _isBusy ? null : _manualDriveBackup,
                ),
              ),
              const SizedBox(height: 16),
              _SectionLabel('データ管理'),
              _SettingsTile(
                icon: Icons.download_outlined,
                title: 'データを保存する（バックアップ）',
                subtitle: 'すべての記録をファイルとしてダウンロードします',
                loading: _isBusy,
                onTap: _isBusy ? null : _downloadZip,
              ),
              _SettingsTile(
                icon: Icons.upload_file_outlined,
                title: '保存したデータを読み込む（復元）',
                subtitle: '以前保存したバックアップファイルからデータを復元します',
                loading: _isBusy,
                onTap: _isBusy ? null : _uploadZip,
              ),
              _SettingsTile(
                icon: Icons.table_chart_outlined,
                title: 'Excelで表示用にダウンロード',
                subtitle: 'Excelで開ける形式でダウンロード（医師への報告書作成に便利）',
                loading: _isBusy,
                onTap: _isBusy ? null : _exportCsv,
              ),
              _SettingsTile(
                icon: Icons.monitor_weight_outlined,
                title: '体重記録をダウンロード (CSV)',
                subtitle: '体重の記録をExcelで開ける形式でダウンロードします',
                loading: _isBusy,
                onTap: _isBusy ? null : _exportWeightCsv,
              ),
              _SettingsTile(
                icon: Icons.favorite_outline,
                title: '血圧記録をダウンロード (CSV)',
                subtitle: '血圧・脈拍の記録をExcelで開ける形式でダウンロードします',
                loading: _isBusy,
                onTap: _isBusy ? null : _exportBloodPressureCsv,
              ),
              const SizedBox(height: 16),
              _SectionLabel('印刷'),
              _SettingsTile(
                icon: Icons.print_outlined,
                title: '印刷・PDF出力',
                subtitle: '医師への報告書をPDFで作成・印刷します',
                onTap: () => _snack('実装予定: PDF印刷'),
              ),
              const SizedBox(height: 16),
              _SectionLabel('アカウント'),
              Consumer<AppProvider>(
                builder: (_, provider, __) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: provider.userPhotoUrl != null
                          ? NetworkImage(provider.userPhotoUrl!)
                          : null,
                      child: provider.userPhotoUrl == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(provider.userName ?? 'ユーザー',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(provider.userEmail ?? '',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withOpacity(0.5))),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.logout,
                title: 'ログアウト',
                subtitle: 'Googleアカウントからログアウトします',
                iconColor: Colors.red,
                titleColor: Colors.red,
                onTap: () => _confirmLogout(context),
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'データはFirestoreにリアルタイムで同期されます',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(0.35),
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          // 処理中オーバーレイ
          if (_isBusy)
            const ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AppProvider>().logout();
    }
  }
}

// ─── Drive バックアップカード ──────────────────────────────────

class _DriveBackupCard extends StatelessWidget {
  final bool enabled;
  final String? lastBackupDate;
  final bool isRunning;
  final VoidCallback? onEnable;
  final VoidCallback? onDisable;
  final VoidCallback? onBackupNow;

  const _DriveBackupCard({
    required this.enabled,
    required this.lastBackupDate,
    required this.isRunning,
    this.onEnable,
    this.onDisable,
    this.onBackupNow,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  enabled ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  color: enabled ? Colors.green : cs.onSurface.withOpacity(0.4),
                ),
                const SizedBox(width: 8),
                Text(
                  enabled ? '有効' : '無効',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.green : cs.onSurface.withOpacity(0.5),
                  ),
                ),
                if (isRunning) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 4),
                  Text('バックアップ中...',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              enabled
                  ? (lastBackupDate != null
                      ? '最終バックアップ: $lastBackupDate　/ 1週間分を保持'
                      : 'バックアップ未実施（次回アプリ起動時に自動実行）')
                  : 'アプリを開くたびに自動でGoogleドライブへ保存します（1週間分）',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.55),
                  ),
            ),
            const SizedBox(height: 12),
            if (!enabled)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isRunning ? null : onEnable,
                  icon: const Icon(Icons.add_link, size: 18),
                  label: const Text('Googleドライブと連携する'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isRunning ? null : onBackupNow,
                      icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                      label: const Text('今すぐ保存'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: isRunning ? null : onDisable,
                    style:
                        TextButton.styleFrom(foregroundColor: cs.onSurface.withOpacity(0.4)),
                    child: const Text('無効にする'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;
  final bool loading;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? cs.primary),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: titleColor,
          ),
        ),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
        trailing: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.3)),
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
