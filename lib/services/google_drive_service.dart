import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

// index.html に定義されているグローバル JS 関数を宣言
@JS('gisInit')
external bool gisInit(String clientId, String scope);

@JS('gisRequestToken')
external void gisRequestToken(String prompt, JSFunction callback);

class GoogleDriveService {
  static const _clientId =
      '208818382983-5ruq2cs0jak59590f2q8eop7mkurm3q6.apps.googleusercontent.com';
  static const _scope = 'https://www.googleapis.com/auth/drive.file';
  static const _folderName = '腹膜透析バックアップ';
  static const _maxBackups = 7;

  bool _gisInitialized = false;

  // ─── GIS 初期化 ────────────────────────────────────────────

  /// GISが読み込まれるまで最大3秒待ってから初期化する。
  Future<bool> _ensureGisInitialized() async {
    if (_gisInitialized) return true;
    for (var i = 0; i < 6; i++) {
      try {
        final ok = gisInit(_clientId, _scope);
        if (ok) {
          _gisInitialized = true;
          return true;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  // ─── アクセストークン取得 ──────────────────────────────────

  /// [forceConsent] = true のとき同意ダイアログを強制表示する（初回有効化時）。
  /// false のときはサイレント取得（同意済みなら無音）。
  Future<String?> getAccessToken({bool forceConsent = false}) async {
    if (!await _ensureGisInitialized()) return null;

    final completer = Completer<String?>();

    // JS から渡される文字列は JSString 型なので .toDart で変換する
    void onToken(JSString jsonResultJS) {
      if (completer.isCompleted) return;
      final data = jsonDecode(jsonResultJS.toDart) as Map<String, dynamic>;
      if (data['error'] != null) {
        completer.complete(null);
      } else {
        completer.complete(data['access_token'] as String?);
      }
    }

    gisRequestToken(forceConsent ? 'consent' : '', onToken.toJS);

    final timeoutSec = forceConsent ? 120 : 15;
    return completer.future.timeout(
      Duration(seconds: timeoutSec),
      onTimeout: () => null,
    );
  }

  // ─── バックアップ実行 ──────────────────────────────────────

  /// ZIPバイト列をGoogleドライブにアップロードし、7日以上古いファイルを削除する。
  /// [silent] = true のとき例外を投げずに失敗を無視する。
  Future<bool> runBackup(Uint8List zipBytes, String dateKey,
      {bool silent = false, bool forceConsent = false}) async {
    try {
      final token = await getAccessToken(forceConsent: forceConsent);
      if (token == null) {
        if (silent) return false;
        throw Exception('Googleドライブへのアクセス権限がありません');
      }

      final folderId = await _getOrCreateFolder(token);
      await _uploadFile(token, folderId, 'pd_backup_$dateKey.zip', zipBytes);
      await _cleanOldBackups(token, folderId);
      return true;
    } catch (e) {
      if (silent) return false;
      rethrow;
    }
  }

  // ─── Drive API ────────────────────────────────────────────

  Future<String> _getOrCreateFolder(String token) async {
    final q = Uri.encodeComponent(
        "name='$_folderName' "
        "and mimeType='application/vnd.google-apps.folder' "
        "and trashed=false");
    final resp = await http.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files'
          '?q=$q&fields=files(id)&pageSize=1'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _checkStatus(resp, 'フォルダ検索');

    final files = (jsonDecode(resp.body)['files'] as List?) ?? [];
    if (files.isNotEmpty) return files.first['id'] as String;

    // フォルダが存在しないので作成
    final createResp = await http.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': _folderName,
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );
    _checkStatus(createResp, 'フォルダ作成');
    return (jsonDecode(createResp.body) as Map<String, dynamic>)['id'] as String;
  }

  Future<void> _uploadFile(
      String token, String folderId, String filename, Uint8List bytes) async {
    const boundary = 'pd_multipart_boundary';
    final meta = jsonEncode({'name': filename, 'parents': [folderId]});

    final bodyBytes = Uint8List.fromList([
      ...utf8.encode('--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '$meta\r\n'
          '--$boundary\r\n'
          'Content-Type: application/zip\r\n\r\n'),
      ...bytes,
      ...utf8.encode('\r\n--$boundary--'),
    ]);

    final resp = await http.post(
      Uri.parse('https://www.googleapis.com/upload/drive/v3/files'
          '?uploadType=multipart'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: bodyBytes,
    );
    _checkStatus(resp, 'ファイルアップロード');
  }

  Future<void> _cleanOldBackups(String token, String folderId) async {
    final q = Uri.encodeComponent(
        "'$folderId' in parents "
        "and name contains 'pd_backup_' "
        "and trashed=false");
    final resp = await http.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files'
          '?q=$q&fields=files(id,name)&orderBy=name&pageSize=20'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _checkStatus(resp, 'ファイル一覧取得');

    final files = ((jsonDecode(resp.body)['files'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .where((f) => (f['name'] as String).endsWith('.zip'))
        .toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    // 古いものから削除（最新 _maxBackups 件だけ残す）
    if (files.length > _maxBackups) {
      final toDelete = files.sublist(0, files.length - _maxBackups);
      for (final file in toDelete) {
        await http.delete(
          Uri.parse('https://www.googleapis.com/drive/v3/files/${file['id']}'),
          headers: {'Authorization': 'Bearer $token'},
        );
      }
    }
  }

  void _checkStatus(http.Response resp, String op) {
    if (resp.statusCode >= 400) {
      throw Exception('Drive API エラー ($op): ${resp.statusCode} ${resp.body}');
    }
  }
}
