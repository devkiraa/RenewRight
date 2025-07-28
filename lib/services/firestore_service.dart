// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // --- Customer Functions ---

  Stream<List<Customer>> getCustomers() {
    return _db.collection('customers').orderBy('name').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList());
  }

  Future<DocumentReference> addCustomer(Customer customer) {
    return _db.collection('customers').add(customer.toJson());
  }

  Future<void> updateCustomer(String customerId, Map<String, dynamic> data) {
    return _db.collection('customers').doc(customerId).update(data);
  }

  Future<void> deleteCustomer(String customerId) async {
    final WriteBatch batch = _db.batch();
    
    final vehiclesSnapshot = await _db.collection('vehicles').where('customerId', isEqualTo: customerId).get();
    
    for (final doc in vehiclesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    batch.delete(_db.collection('customers').doc(customerId));
    
    await batch.commit();
  }

  // --- Vehicle Functions ---

  Stream<List<Vehicle>> getVehiclesForCustomer(String customerId) {
    return _db
        .collection('vehicles')
        .where('customerId', isEqualTo: customerId)
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Vehicle.fromFirestore(doc)).toList());
  }

  Future<void> addVehicle(Vehicle vehicle) {
    return _db.collection('vehicles').add(vehicle.toJson());
  }
  
  Future<void> updateVehicle(String vehicleId, Map<String, dynamic> data) {
    return _db.collection('vehicles').doc(vehicleId).update(data);
  }

  Future<void> deleteVehicle(String vehicleId) {
    return _db.collection('vehicles').doc(vehicleId).delete();
  }
  
  Future<void> addNoteToVehicle(String vehicleId, String note) {
    return _db.collection('vehicles').doc(vehicleId).update({
      'activityLog': FieldValue.arrayUnion([
        {'timestamp': Timestamp.now(), 'note': note}
      ])
    });
  }

  // --- User Functions ---

  Future<AppUser?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return AppUser.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<void> createUserRecord(AppUser user) {
    return _db.collection('users').doc(user.uid).set(user.toJson());
  }
  
  Future<bool> isFirstUser() async {
    final snapshot = await _db.collection('users').limit(1).get();
    return snapshot.docs.isEmpty;
  }
  
  Stream<List<AppUser>> getEmployees() {
    return _db.collection('users').where('role', isEqualTo: 'employee').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList();
    });
  }
  
  Future<void> addEmployee(String phoneNumber) async {
    await _db.collection('users').doc(phoneNumber).set({
      'phoneNumber': phoneNumber,
      'role': 'employee',
      'preRegistered': true,
    });
  }
  
  Future<void> removeEmployee(String uid) {
    return _db.collection('users').doc(uid).delete();
  }

  // --- Dashboard Functions ---

  Future<Map<String, dynamic>> getDashboardStats() async {
    final now = DateTime.now();
    
    final customerCountSnapshot = await _db.collection('customers').count().get();
    final totalCustomers = customerCountSnapshot.count ?? 0;

    final upcomingSnapshot = await _db.collection('vehicles')
      .where('dueDate', isGreaterThan: Timestamp.fromDate(now))
      .where('dueDate', isLessThan: Timestamp.fromDate(now.add(const Duration(days: 30))))
      .count()
      .get();
    final upcomingRenewals = upcomingSnapshot.count ?? 0;

    final vehicleCountSnapshot = await _db.collection('vehicles').count().get();
    final totalVehicles = vehicleCountSnapshot.count ?? 0;

    return {
      'totalCustomers': totalCustomers,
      'totalVehicles': totalVehicles,
      'upcomingRenewals': upcomingRenewals,
    };
  }
  // NEW: Fetches a list of the next vehicles due for renewal
  Future<List<Vehicle>> getUpcomingRenewals({int limit = 5}) async {
    final now = DateTime.now();
    try {
      final snapshot = await _db
          .collection('vehicles')
          .where('dueDate', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('dueDate', descending: false)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => Vehicle.fromFirestore(doc)).toList();
    } catch (e) {
      // This catch block can help identify if an index is missing.
      print('Error fetching upcoming renewals: $e');
      rethrow;
    }
  }
}