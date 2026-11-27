import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../core/config/app_config.dart';
import '../core/errors/service_error.dart';

class AuthService {
  final AppConfig _config;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService(
    this._config, {
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  // Stream to listen to Authentication State changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current authenticated user
  User? get currentUser => _auth.currentUser;

  // Get current user ID
  String? get currentUid => _auth.currentUser?.uid;

  // Sign In with Email and Password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with Email, Password and Name
  Future<UserCredential> registerWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // 1. Create user in Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = credential.user!.uid;

      // 2. Create corresponding User Profile in Firestore
      final userModel = UserModel(
        uid: uid,
        name: name,
        email: email,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(_config.firestore.collectionUsers)
          .doc(uid)
          .set(userModel.toMap());

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Fetch User Details from Firestore
  Future<UserModel?> getUserDetails(String uid) async {
    try {
      final doc = await _firestore.collection(_config.firestore.collectionUsers).doc(uid).get();
      if (doc.exists) {
        return UserModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      throw DataException('getUserDetails', e);
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Error Helper
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'weak-password':
        return 'The password is too weak.';
      default:
        return e.message ?? 'An unknown authentication error occurred.';
    }
  }
}
