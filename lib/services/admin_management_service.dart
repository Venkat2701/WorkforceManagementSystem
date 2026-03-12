import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminManagementServiceProvider = Provider(
  (ref) => AdminManagementService(),
);

class AdminManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> fetchAdmins() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .snapshots();
  }

  Stream<QuerySnapshot> fetchAdminLogs(String uid) {
    return _firestore
        .collection('auth_logs')
        .where('uid', isEqualTo: uid)
        .limit(50)
        .snapshots();
  }

  Future<void> createAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    // Check for existing name in Firestore (ignoring deactivated accounts)
    final nameCheck = await _firestore
        .collection('users')
        .where('name', isEqualTo: name)
        .get();

    for (var doc in nameCheck.docs) {
      final role = doc.data()['role'];
      if (role != 'deactivated_admin') {
        throw Exception('An admin with this name already exists.');
      }
    }

    // To create a user without logging out the current superadmin,
    // we use a secondary Firebase app instance.
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp',
      options: Firebase.app().options,
    );

    try {
      UserCredential credential = await FirebaseAuth.instanceFor(
        app: secondaryApp,
      ).createUserWithEmailAndPassword(email: email, password: password);

      if (credential.user != null) {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'name': name,
          'email': email,
          'role': 'admin',
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'email-already-in-use') {
        // Handle re-activation of soft-deleted admin
        final query = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .get();

        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          final role = doc.data()['role'];

          if (role == 'deactivated_admin') {
            await doc.reference.update({
              'role': 'admin',
              'name': name,
              'temp_password': password,
              'password_reset_required': true,
              'updated_at': FieldValue.serverTimestamp(),
            });
            // Throw a specific message so UI can show success/re-activation
            throw Exception('RE_ACTIVATED');
          }
        }
      }
      rethrow;
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<void> deleteAdmin(String uid) async {
    // Soft delete: update role to 'deactivated_admin'
    // This removes them from fetchAdmins query while keeping their record
    await _firestore.collection('users').doc(uid).update({
      'role': 'deactivated_admin',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendPasswordReset(String email) async {
    // This is the standard, secure way to reset a password in Firebase.
    // It sends an email to the administrator with a link to set a new password.
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }
}
