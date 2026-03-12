import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

final authServiceProvider = Provider((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final userRoleProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  return doc.data()?['role'] as String?;
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check for allowed roles
      final userDocRef = _firestore
          .collection('users')
          .doc(credential.user?.uid);
      final userDoc = await userDocRef.get();
      final data = userDoc.data();
      final role = data?['role'];

      if (userDoc.exists && (role == 'superadmin' || role == 'admin')) {
        // Sync email and last login if missing or changed
        await userDocRef.set({
          'email': credential.user!.email,
          'last_login': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Log sign-in event
        await _logAuthEvent(
          credential.user!.uid,
          credential.user!.email ?? '',
          'SIGN_IN',
        );
        return credential;
      } else {
        await _auth.signOut();
        throw Exception('Access denied. Admin role required.');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _logAuthEvent(user.uid, user.email ?? '', 'SIGN_OUT');
    }
    await _auth.signOut();
  }

  Future<void> _logAuthEvent(String uid, String email, String type) async {
    try {
      await _firestore.collection('auth_logs').add({
        'uid': uid,
        'email': email,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging auth event: $e');
    }
  }
}
