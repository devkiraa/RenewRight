// lib/screens/employee_management_screen.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  void _showAddEmployeeDialog() {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Employee'),
          content: TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Employee\'s 10-digit number',
              prefixText: '+91 ',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final phone = "+91${phoneController.text.trim()}";
                if (phone.length == 13) {
                  _firestoreService.addEmployee(phone);
                  Navigator.of(context).pop();
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Employee record for $phone created.')));
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // NEW: Confirmation dialog for removing an employee
  void _confirmRemoveEmployee(AppUser employee) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: Text('Are you sure you want to remove ${employee.phoneNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _firestoreService.removeEmployee(employee.uid);
              Navigator.of(ctx).pop();
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Employees')),
      body: StreamBuilder<List<AppUser>>(
        stream: _firestoreService.getEmployees(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final employees = snapshot.data ?? [];
          if (employees.isEmpty) {
            return const Center(child: Text('No employees found.'));
          }
          return ListView.builder(
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final employee = employees[index];
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(employee.phoneNumber),
                subtitle: Text(employee.role),
                // NEW: Trailing delete button
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Remove Employee',
                  onPressed: () => _confirmRemoveEmployee(employee),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEmployeeDialog,
        tooltip: 'Add Employee',
        child: const Icon(Icons.add),
      ),
    );
  }
}