// lib/screens/add_edit_vehicle_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';
import '../models/vehicle_model.dart';
import '../services/firestore_service.dart';
import 'image_viewer_screen.dart';

// A robust formatter for all Indian vehicle number formats
class VehicleNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final buffer = StringBuffer();

    // Check if it's a BH-series plate
    if (text.startsWith(RegExp(r'\d{2}BH'))) {
      for (int i = 0; i < text.length; i++) {
        buffer.write(text[i]);
        if (i == 1) buffer.write('-'); // XX-
        if (i == 3) buffer.write('-'); // XX-BH-
        if (i == 7) buffer.write('-'); // XX-BH-NNNN-
      }
    } else { // Handle standard plates
      int? seriesEndIndex;
      if (text.length > 4) {
        for (int i = 4; i < text.length; i++) {
          if (RegExp(r'[0-9]').hasMatch(text[i])) {
            seriesEndIndex = i;
            break;
          }
        }
      }

      for (int i = 0; i < text.length; i++) {
        buffer.write(text[i]);
        if (i == 1 && text.length > 2) buffer.write('-');
        if (i == 3 && text.length > 4) buffer.write('-');
        if (seriesEndIndex != null && i == seriesEndIndex - 1 && i > 3) buffer.write('-');
      }
    }
    
    var formattedText = buffer.toString();
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}


class AddEditVehicleScreen extends StatefulWidget {
  final Customer customer;
  final Vehicle? vehicle;

  const AddEditVehicleScreen({super.key, required this.customer, this.vehicle});

  @override
  State<AddEditVehicleScreen> createState() => _AddEditVehicleScreenState();
}

class _AddEditVehicleScreenState extends State<AddEditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  late bool _isEditMode;

  final _vehicleNumberController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedVehicleType;
  DateTime? _insuranceStartDate;
  String? _selectedInsurancePeriod;
  DateTime? _calculatedDueDate;
  Map<String, String> _photoBase64Map = {};
  bool _isLoading = false;

  final List<String> _vehicleTypes = ['Car', 'Scooter', 'Bike', 'Truck', 'Mini Truck', 'Bus', 'Other'];
  final List<String> _insurancePeriods = ['3 Months', '6 Months', '1 Year', '2 Years', '3 Years'];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.vehicle != null;
    if (_isEditMode) {
      final v = widget.vehicle!;
      _vehicleNumberController.text = v.vehicleNumber;
      _selectedVehicleType = v.vehicleType;
      _insuranceStartDate = v.insuranceStartDate;
      _selectedInsurancePeriod = v.insurancePeriod;
      _photoBase64Map = Map.from(v.photos);
      _calculateDueDate();
    }
  }
  
  void _calculateDueDate() {
    if (_insuranceStartDate != null && _selectedInsurancePeriod != null) {
      int monthsToAdd = 0;
      switch (_selectedInsurancePeriod) {
        case '3 Months': monthsToAdd = 3; break;
        case '6 Months': monthsToAdd = 6; break;
        case '1 Year': monthsToAdd = 12; break;
        case '2 Years': monthsToAdd = 24; break;
        case '3 Years': monthsToAdd = 36; break;
      }
      setState(() => _calculatedDueDate = DateTime(_insuranceStartDate!.year, _insuranceStartDate!.month + monthsToAdd, _insuranceStartDate!.day));
    }
  }

  Future<void> _pickImage(String label) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      final imageBytes = await image.readAsBytes();
      final base64String = base64Encode(imageBytes);
      setState(() => _photoBase64Map[label] = base64String);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(context: context, initialDate: _insuranceStartDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
    if (picked != null) {
      setState(() => _insuranceStartDate = picked);
      _calculateDueDate();
    }
  }

  void _saveVehicle() async {
    if (!_formKey.currentState!.validate() || _calculatedDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
      return;
    }
    setState(() => _isLoading = true);
    
    if (_isEditMode) {
      final vehicleDataMap = {
        'customerName': widget.customer.name,
        'vehicleNumber': _vehicleNumberController.text, 
        'vehicleType': _selectedVehicleType!, 
        'insuranceStartDate': Timestamp.fromDate(_insuranceStartDate!),
        'insurancePeriod': _selectedInsurancePeriod!, 
        'dueDate': Timestamp.fromDate(_calculatedDueDate!), 
        'photos': _photoBase64Map,
      };
      await _firestoreService.updateVehicle(widget.vehicle!.id, vehicleDataMap);
    } else {
      final newVehicle = Vehicle(
        id: '', 
        customerId: widget.customer.id, 
        customerName: widget.customer.name,
        vehicleNumber: _vehicleNumberController.text, 
        vehicleType: _selectedVehicleType!,
        insuranceStartDate: _insuranceStartDate!, 
        insurancePeriod: _selectedInsurancePeriod!, 
        dueDate: _calculatedDueDate!, 
        photos: _photoBase64Map,
      );
      await _firestoreService.addVehicle(newVehicle);
    }
    
    if (mounted) Navigator.of(context).pop();
  }

  void _addNote() {
    if (_noteController.text.trim().isEmpty || !_isEditMode) return;
    _firestoreService.addNoteToVehicle(widget.vehicle!.id, _noteController.text.trim());
    _noteController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditMode ? 'Edit Vehicle' : 'Add New Vehicle')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Card(
                    elevation: 2.0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Vehicle Details", style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _vehicleNumberController,
                            decoration: const InputDecoration(labelText: 'Vehicle Number', prefixIcon: Icon(Icons.pin_outlined), border: OutlineInputBorder()),
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(15),
                              VehicleNumberFormatter(),
                            ],
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedVehicleType,
                            decoration: const InputDecoration(labelText: 'Vehicle Type', prefixIcon: Icon(Icons.directions_car_filled_outlined), border: OutlineInputBorder()),
                            items: _vehicleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setState(() => _selectedVehicleType = v),
                            validator: (v) => v == null ? 'Please select a type' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2.0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Insurance Details", style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 20),
                          InkWell(
                            onTap: () => _selectDate(context),
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Insurance Start Date', prefixIcon: Icon(Icons.calendar_today_outlined), border: OutlineInputBorder()),
                              child: Text(_insuranceStartDate == null ? 'Select Date' : DateFormat.yMMMd().format(_insuranceStartDate!)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedInsurancePeriod,
                            decoration: const InputDecoration(labelText: 'Insurance Period', prefixIcon: Icon(Icons.timelapse_outlined), border: OutlineInputBorder()),
                            items: _insurancePeriods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                            onChanged: (v) { setState(() => _selectedInsurancePeriod = v); _calculateDueDate(); },
                            validator: (v) => v == null ? 'Please select a period' : null,
                          ),
                          const SizedBox(height: 20),
                          if (_calculatedDueDate != null) Center(child: Chip(avatar: const Icon(Icons.event_available_outlined, color: Colors.white), label: Text('Next Renewal: ${DateFormat.yMMMd().format(_calculatedDueDate!)}'), labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), backgroundColor: Theme.of(context).primaryColor)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2.0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Documents", style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8.0, runSpacing: 4.0,
                            children: [
                              ElevatedButton.icon(icon: const Icon(Icons.badge_outlined), label: const Text("Aadhar"), onPressed: () => _pickImage("Aadhar")),
                              ElevatedButton.icon(icon: const Icon(Icons.drive_eta_outlined), label: const Text("RC"), onPressed: () => _pickImage("RC")),
                              ElevatedButton.icon(icon: const Icon(Icons.shield_outlined), label: const Text("Insurance"), onPressed: () => _pickImage("Insurance")),
                              ElevatedButton.icon(icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text("Other"), onPressed: () => _pickImage("Other")),
                            ],
                          ),
                          if (_photoBase64Map.isNotEmpty) ...[
                            const Divider(height: 24),
                            ..._photoBase64Map.entries.map((entry) => ListTile(
                              leading: Image.memory(base64Decode(entry.value), width: 40, height: 40, fit: BoxFit.cover),
                              title: Text(entry.key),
                              trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), tooltip: 'Remove', onPressed: () => setState(() => _photoBase64Map.remove(entry.key))),
                              dense: true,
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ImageViewerScreen(base64Image: entry.value, title: entry.key),
                                ));
                              },
                            )),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_isEditMode) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Activity Log", style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 10),
                            if (widget.vehicle!.activityLog.isEmpty) const Text('No notes added yet.'),
                            ...widget.vehicle!.activityLog.reversed.map((log) => ListTile(
                                leading: const Icon(Icons.note_alt_outlined),
                                title: Text(log['note']),
                                subtitle: Text(DateFormat.yMMMd().add_jm().format((log['timestamp'] as Timestamp).toDate())),
                              )),
                            const Divider(),
                            Row(
                              children: [
                                Expanded(child: TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'Add a new note...'))),
                                IconButton(icon: const Icon(Icons.add_comment), onPressed: _addNote),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: Text(_isEditMode ? 'Update Vehicle' : 'Save Vehicle'),
          onPressed: _saveVehicle,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}