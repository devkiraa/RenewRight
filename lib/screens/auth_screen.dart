// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  
  bool _isLoginMode = true; // To toggle between Login and Signup
  bool _isLoading = false;

  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() { _isLoading = true; });

    final phone = "+91${_phoneController.text.trim()}";
    final password = _passwordController.text.trim();
    bool success;

    if (_isLoginMode) {
      success = await _authService.signInWithPhoneAndPassword(phone, password);
    } else {
      success = await _authService.signUpWithPhoneAndPassword(phone, password);
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_isLoginMode ? 'Login' : 'Signup'} Failed. Please try again.')),
      );
    }
    
    if (mounted) {
      setState(() { _isLoading = false; });
    }
    // Navigation is handled by the auth state stream in main.dart
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Insurance Manager',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoginMode ? 'Welcome back! Please login.' : 'Create your account.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: '10-digit mobile number',
                    prefixText: '+91 ',
                    border: OutlineInputBorder(),
                    counterText: "",
                  ),
                  validator: (value) => value!.length != 10 ? 'Enter a valid 10-digit number' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _submit,
                          child: Text(_isLoginMode ? 'Login' : 'Sign Up'),
                        ),
                      ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                    });
                  },
                  child: Text(_isLoginMode ? 'Don\'t have an account? Sign Up' : 'Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}