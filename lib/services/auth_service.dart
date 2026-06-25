import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Stream<User?> get userStream => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signInWithGoogle() async {
    // Web PWA: ポップアップ経由でサインイン
    final provider = GoogleAuthProvider();
    await _auth.signInWithPopup(provider);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
