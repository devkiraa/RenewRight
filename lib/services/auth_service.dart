// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Signs up a new user with phone (as email) and password
  Future<bool> signUpWithPhoneAndPassword(String phoneNumber, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        // We use the phone number as the email for Firebase Auth
        email: "$phoneNumber@csc.app", // Append a dummy domain
        password: password,
      );
      final user = userCredential.user;

      if (user != null) {
        // Create a user record in Firestore
        final isFirst = await _firestoreService.isFirstUser();
        final newUser = AppUser(
          uid: user.uid,
          phoneNumber: phoneNumber,
          role: isFirst ? 'admin' : 'employee',
        );
        await _firestoreService.createUserRecord(newUser);
        return true;
      }
      return false;
    } catch (e) {
      print(e);
      return false;
    }
  }

  // Signs in an existing user
  Future<bool> signInWithPhoneAndPassword(String phoneNumber, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: "$phoneNumber@csc.app", // Use the same format
        password: password,
      );
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  // Signs the user out
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Gets the current logged-in user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
  
  // Provides a stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}