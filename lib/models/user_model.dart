// lib/models/user_model.dart
class AppUser {
  final String uid;
  final String phoneNumber;
  final String role; // 'admin' or 'employee'

  AppUser({
    required this.uid,
    required this.phoneNumber,
    required this.role,
  });

  // Create an AppUser from a Firestore document
  factory AppUser.fromFirestore(Map<String, dynamic> data, String documentId) {
    return AppUser(
      uid: documentId,
      phoneNumber: data['phoneNumber'] ?? '',
      role: data['role'] ?? 'employee',
    );
  }

  // Convert an AppUser object to a Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': phoneNumber,
      'role': role,
    };
  }
}