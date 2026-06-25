import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  // 写真をアップロードしてStorageパスを返す
  Future<String> uploadPhoto(Uint8List bytes, String uid) async {
    final path =
        'users/$uid/photos/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return path;
  }

  // StorageパスからダウンロードURLを取得
  Future<String> getDownloadUrl(String storagePath) async {
    return await _storage.ref(storagePath).getDownloadURL();
  }
}
