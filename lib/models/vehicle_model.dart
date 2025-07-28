// lib/models/vehicle_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String id;
  final String customerId;
  final String vehicleNumber;
  final String vehicleType;
  final DateTime insuranceStartDate;
  final String insurancePeriod;
  final DateTime dueDate;
  final Map<String, String> photos;
  final List<Map<String, dynamic>> activityLog; // NEW: For notes

  Vehicle({
    required this.id,
    required this.customerId,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.insuranceStartDate,
    required this.insurancePeriod,
    required this.dueDate,
    this.photos = const {},
    this.activityLog = const [], // NEW
  });

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Vehicle(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      vehicleNumber: data['vehicleNumber'] ?? '',
      vehicleType: data['vehicleType'] ?? '',
      insuranceStartDate: (data['insuranceStartDate'] as Timestamp? ?? Timestamp.now()).toDate(),
      insurancePeriod: data['insurancePeriod'] ?? '',
      dueDate: (data['dueDate'] as Timestamp? ?? Timestamp.now()).toDate(),
      photos: Map<String, String>.from(data['photos'] ?? {}),
      // NEW: Load the activity log
      activityLog: List<Map<String, dynamic>>.from(data['activityLog'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'vehicleNumber': vehicleNumber,
      'vehicleType': vehicleType,
      'insuranceStartDate': Timestamp.fromDate(insuranceStartDate),
      'insurancePeriod': insurancePeriod,
      'dueDate': Timestamp.fromDate(dueDate),
      'photos': photos,
      'activityLog': activityLog, // NEW
    };
  }
}