import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authState => _auth.authStateChanges();

  Future<User?> signInAnonymously() async {
    final result = await _auth.signInAnonymously();
    return result.user;
  }

  Future<void> setupProfile(String uid, String name, String avatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playerName', name);
    await prefs.setString('playerAvatar', avatar);

    await _db.collection('users').doc(uid).set({
      'name': name,
      'avatar': avatar,
      'totalMatches': 0,
      'wins': 0,
      'losses': 0,
      'draws': 0,
      'points': 0,
      'winRate': 0.0,
      'currentStreak': 0,
      'bestStreak': 0,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<bool> hasProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists && (doc.data()?['name'] ?? '').toString().isNotEmpty;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
