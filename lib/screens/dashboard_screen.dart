// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/vehicle_model.dart';
import '../services/firestore_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<List<dynamic>> _dashboardDataFuture;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _loadDashboardData() {
    _dashboardDataFuture = Future.wait([
      _firestoreService.getDashboardStats(),
      _firestoreService.getUpcomingRenewals(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _loadDashboardData();
          });
        },
        child: FutureBuilder<List<dynamic>>(
          future: _dashboardDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading stats. You may need to create a Firestore index.\n\nDetails: ${snapshot.error}', textAlign: TextAlign.center),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No data available.'));
            }

            final Map<String, dynamic> stats = snapshot.data![0];
            final List<Vehicle> upcomingVehicles = snapshot.data![1];
            
            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  // UPDATED: Give cards more height to prevent overflow
                  childAspectRatio: 1.2, 
                  children: [
                    _buildStatCard(icon: Icons.people, color: Colors.blue, title: 'Total Customers', value: stats['totalCustomers']?.toString() ?? '0'),
                    _buildStatCard(icon: Icons.directions_car, color: Colors.purple, title: 'Total Vehicles', value: stats['totalVehicles']?.toString() ?? '0'),
                    // This card is wider now, spanning the full width
                    _buildStatCard(icon: Icons.event_available, color: Colors.orange, title: 'Due in 30 Days', value: stats['upcomingRenewals']?.toString() ?? '0', isFullWidth: true),
                  ],
                ),
                const SizedBox(height: 24),

                Text('Next 5 Upcoming Renewals', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (upcomingVehicles.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No upcoming renewals found.'))),
                ...upcomingVehicles.map((vehicle) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(vehicle.vehicleNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(vehicle.vehicleType),
                    trailing: Text(
                      '${vehicle.dueDate.difference(DateTime.now()).inDays + 1} days left',
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                )),
              ],
            );
          },
        ),
      ),
    );
  }

  // UPDATED: This widget is redesigned to prevent overflowing
  Widget _buildStatCard({required IconData icon, required Color color, required String title, required String value, bool isFullWidth = false}) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // Make the third card span the full width if needed
      child: Container(
         width: isFullWidth ? double.infinity : null,
         padding: const EdgeInsets.all(16.0),
         child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Use spaceBetween instead of Spacer
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: color),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade700)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28, // Adjusted font size
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}