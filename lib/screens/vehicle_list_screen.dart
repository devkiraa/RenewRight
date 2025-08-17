// lib/screens/vehicle_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer_model.dart';
import '../models/vehicle_model.dart';
import '../services/firestore_service.dart';
import 'add_edit_vehicle_screen.dart';

class VehicleListScreen extends StatefulWidget {
  final Customer customer;
  const VehicleListScreen({super.key, required this.customer});
  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _activeFilter = 'All';

  IconData _getVehicleIcon(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'car': return Icons.directions_car;
      case 'bike': case 'scooter': return Icons.two_wheeler;
      case 'truck': case 'mini truck': return Icons.local_shipping;
      case 'bus': return Icons.directions_bus;
      default: return Icons.drive_eta;
    }
  }

  Color _getDueDateColor(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (dueDay.isBefore(today)) {
      return Colors.red.shade700; // Overdue
    }
    final difference = dueDay.difference(today).inDays;
    if (difference < 30) {
      return Colors.orange.shade700; // Due soon
    } else {
      return Colors.green.shade700; // Safe
    }
  }

  void _sendWhatsAppMessage(String phone, String vehicleNumber, DateTime dueDate) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final message = Uri.encodeComponent(
      'Hello ${widget.customer.name},\nThis is a reminder that your insurance for vehicle *$vehicleNumber* is due for renewal on *${DateFormat.yMMMd().format(dueDate)}*.\n\nPlease contact us to proceed.\nThank you.'
    );
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$message');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.customer.name),
            if (widget.customer.phone.isNotEmpty)
              Text(
                widget.customer.phone,
                style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8.0,
              children: [
                ChoiceChip(label: const Text('All'), selected: _activeFilter == 'All', onSelected: (s) => {if (s) setState(() => _activeFilter = 'All')}),
                ChoiceChip(label: const Text('Due in 30 Days'), selected: _activeFilter == 'DueSoon', onSelected: (s) => {if (s) setState(() => _activeFilter = 'DueSoon')}),
                ChoiceChip(label: const Text('Overdue'), selected: _activeFilter == 'Overdue', onSelected: (s) => {if (s) setState(() => _activeFilter = 'Overdue')}),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Vehicle>>(
              stream: _firestoreService.getVehiclesForCustomer(widget.customer.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('An error occurred: ${snapshot.error}'));
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No vehicles found.\nTap the "+" button to add one!', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)));

                List<Vehicle> vehicles = snapshot.data!;
                final now = DateTime.now();
                if (_activeFilter == 'DueSoon') {
                  vehicles = vehicles.where((v) => v.dueDate.isAfter(now) && v.dueDate.difference(now).inDays <= 30).toList();
                } else if (_activeFilter == 'Overdue') {
                  vehicles = vehicles.where((v) => v.dueDate.isBefore(now)).toList();
                }

                if (vehicles.isEmpty) return const Center(child: Text('No vehicles match your criteria.', style: TextStyle(fontSize: 16, color: Colors.grey)));

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: vehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = vehicles[index];
                    final dueDateColor = _getDueDateColor(vehicle.dueDate);
                    return Card(
                      elevation: 4.0,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddEditVehicleScreen(customer: widget.customer, vehicle: vehicle))),
                        borderRadius: BorderRadius.circular(12.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(_getVehicleIcon(vehicle.vehicleType), color: Theme.of(context).primaryColor),
                                  const SizedBox(width: 8),
                                  Text(vehicle.vehicleType, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  if (widget.customer.phone.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.message_outlined),
                                      color: Colors.green.shade600,
                                      tooltip: 'Send WhatsApp Reminder',
                                      onPressed: () => _sendWhatsAppMessage(widget.customer.phone, vehicle.vehicleNumber, vehicle.dueDate),
                                    ),
                                ],
                              ),
                              const Divider(height: 20),
                              Text(vehicle.vehicleNumber, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: dueDateColor),
                                  const SizedBox(width: 8),
                                  Text('Renewal Due: ${DateFormat.yMMMd().format(vehicle.dueDate)}', style: TextStyle(color: dueDateColor, fontWeight: FontWeight.w600, fontSize: 16)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddEditVehicleScreen(customer: widget.customer))),
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
      ),
    );
  }
}