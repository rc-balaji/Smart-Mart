import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  Future<User> ensureAnonymousUser() async {
    final current = _auth.currentUser;
    if (current != null) return current;
    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) throw StateError('Anonymous sign-in failed.');
    return user;
  }

  Future<String> freshIdToken() async {
    final user = await ensureAnonymousUser();
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) throw StateError('Firebase token unavailable.');
    return token;
  }
}
