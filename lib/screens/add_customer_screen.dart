// lib/screens/add_customer_screen.dart
import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AddCustomerScreen extends StatefulWidget {
  final Customer? customer; // Can be null if adding a new customer

  const AddCustomerScreen({super.key, this.customer});
  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  late bool _isEditMode;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.customer != null;
    if (_isEditMode) {
      _nameController.text = widget.customer!.name;
      _phoneController.text = widget.customer!.phone;
    }
  }

  void _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final user = _authService.getCurrentUser();
      if (user == null) {
        // Handle user not logged in error
        setState(() => _isLoading = false);
        return;
      }

      if (_isEditMode) {
        // Update existing customer
        await _firestoreService.updateCustomer(widget.customer!.id, {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        });
      } else {
        // Add new customer
        final newCustomer = Customer(
          id: '', // Firestore generates the ID
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          createdByUid: user.uid,
        );
        await _firestoreService.addCustomer(newCustomer);
      }
      
      if(mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditMode ? 'Edit Customer' : 'Add New Customer')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _saveCustomer,
                    icon: const Icon(Icons.save),
                    label: Text(_isEditMode ? 'Update Customer' : 'Save Customer'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}