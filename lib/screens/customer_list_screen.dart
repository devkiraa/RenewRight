// lib/screens/customer_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/vehicle_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'add_customer_screen.dart';
import 'dashboard_screen.dart';
import 'employee_management_screen.dart';
import 'vehicle_list_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});
  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _currentUserRole;

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _fetchUserRole();
    _searchController.addListener(() {
      if (mounted) setState(() => _searchQuery = _searchController.text);
    });
  }
  
  void _loadBannerAd() {
    final adUnitId = 'ca-app-pub-7451304293352412/2801466658';
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdReady = true),
        onAdFailedToLoad: (ad, err) {
          print('BannerAd failed to load: $err');
          _isBannerAdReady = false;
          ad.dispose();
        },
      ),
    )..load();
  }

  void _fetchUserRole() async {
    final user = _authService.getCurrentUser();
    if (user != null) {
      final userData = await _firestoreService.getUserData(user.uid);
      if (mounted) setState(() => _currentUserRole = userData?.role);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }
  
  void _showDeleteConfirmation(Customer customer) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete ${customer.name}? This will also delete all of their vehicles.'),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(ctx).pop()),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _firestoreService.deleteCustomer(customer.id);
                if(mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${customer.name} deleted.')));
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RenewRight'),
        actions: [
          if (_currentUserRole == 'admin')
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              tooltip: 'Dashboard',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DashboardScreen())),
            ),
          if (_currentUserRole != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'manage_employees') {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmployeeManagementScreen()));
                } else if (value == 'logout') {
                  _authService.signOut();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (_currentUserRole == 'admin') const PopupMenuItem<String>(value: 'manage_employees', child: Text('Manage Employees')),
                const PopupMenuItem<String>(value: 'logout', child: Text('Logout')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Customer Name or Phone',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                    child: Text('Due in 10 Days', style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
                StreamBuilder<List<Vehicle>>(
                  stream: _firestoreService.getUrgentRenewals(days: 10),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SliverToBoxAdapter(child: Card(margin: EdgeInsets.symmetric(horizontal: 16), child: ListTile(title: Text('No renewals due in the next 10 days.'))));
                    }
                    final urgentVehicles = snapshot.data!;
                    return SliverToBoxAdapter(
                      child: SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          itemCount: urgentVehicles.length,
                          itemBuilder: (context, index) {
                            final vehicle = urgentVehicles[index];
                            final daysLeft = vehicle.dueDate.difference(DateTime.now()).inDays + 1;
                            return Card(
                              color: Colors.orange.shade50,
                              child: Container(
                                width: 220,
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(vehicle.customerName, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                    Text(vehicle.vehicleNumber),
                                    const Spacer(),
                                    Text('$daysLeft day${daysLeft > 1 ? 's' : ''} left', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
                    child: Text('All Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                StreamBuilder<List<Customer>>(
                  stream: _firestoreService.getCustomers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator())));
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return const SliverToBoxAdapter(child: Center(child: Text('No customers found.')));
                    
                    List<Customer> customers = snapshot.data!;
                    if (_searchQuery.isNotEmpty) {
                      customers = customers.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || c.phone.contains(_searchQuery)).toList();
                    }

                    if(customers.isEmpty) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No customers match your search.'))));

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final customer = customers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                            child: ListTile(
                              leading: CircleAvatar(child: Text(customer.name.substring(0, 1).toUpperCase())),
                              title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(customer.phone),
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VehicleListScreen(customer: customer))),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddCustomerScreen(customer: customer)));
                                  else if (value == 'delete') _showDeleteConfirmation(customer);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 8), Text('Edit')])),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 20), SizedBox(width: 8), Text('Delete')])),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: customers.length,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (_isBannerAdReady)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddCustomerScreen())),
        tooltip: 'Add New Customer',
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}