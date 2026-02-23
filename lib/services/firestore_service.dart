import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String language,
  }) async {
    try {
      await _db.collection('users').doc(uid).set({
        'id': uid,
        'name': name,
        'language': language,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Create User Profile Error: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print('Get User Profile Error: $e');
    }
    return null;
  }

  Future<void> updateUserLanguage(String uid, String language) async {
    try {
      await _db.collection('users').doc(uid).update({
        'language': language,
      });
    } catch (e) {
      print('Update Language Error: $e');
    }
  }
}
