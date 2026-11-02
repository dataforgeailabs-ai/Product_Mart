import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class HotelRegistrationScreen extends StatefulWidget {
  const HotelRegistrationScreen({super.key});

  @override
  State<HotelRegistrationScreen> createState() =>
      _HotelRegistrationScreenState();
}

class _HotelRegistrationScreenState
    extends State<HotelRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  final _hotelNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _hotelPhoneController = TextEditingController();
  final _hotelEmailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pinCodeController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _propertyTypeController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _hotelNameController.dispose();
    _contactPersonController.dispose();
    _hotelPhoneController.dispose();
    _hotelEmailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pinCodeController.dispose();
    _gstNumberController.dispose();
    _propertyTypeController.dispose();

    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }

    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an email address';
    }

    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }

    if (value.length < 8) {
      return 'Password must contain at least 8 characters';
    }

    return null;
  }

  String _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['detail'] != null) {
        return data['detail'].toString();
      }

      if (data['error'] != null) {
        return data['error'].toString();
      }

      final errors = <String>[];

      data.forEach((key, value) {
        if (value is List) {
          errors.add('$key: ${value.join(', ')}');
        } else if (value is Map) {
          errors.add('$key: ${value.toString()}');
        } else {
          errors.add('$key: $value');
        }
      });

      if (errors.isNotEmpty) {
        return errors.join('\n');
      }
    }

    return 'Registration failed. Please try again.';
  }

  Future<void> _registerHotel() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final registrationData = {
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text,
        'hotel_name': _hotelNameController.text.trim(),
        'contact_person': _contactPersonController.text.trim(),
        'hotel_phone': _hotelPhoneController.text.trim(),
        'hotel_email': _hotelEmailController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pin_code': _pinCodeController.text.trim(),
        'gst_number': _gstNumberController.text.trim(),
        'property_type': _propertyTypeController.text.trim(),
      };

      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(registrationData),
      );

      dynamic responseData;

      try {
        responseData = jsonDecode(response.body);
      } catch (_) {
        throw Exception(
          'Invalid response received from the server.',
        );
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hotel registration successful! Please sign in.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pop(true);
      } else {
        throw Exception(_extractErrorMessage(responseData));
      }
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().startsWith('Exception: ')
          ? e.toString().substring('Exception: '.length)
          : e.toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 24,
        bottom: 16,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: obscureText ? 1 : maxLines,
        obscureText: obscureText,
        validator: validator ?? _requiredValidator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel Registration'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 550,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.hotel_outlined,
                      size: 65,
                      color: Color(0xFFC41E34),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Register Your Hotel',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your account to start ordering hotel supplies.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),

                    // Account Details
                    _buildSectionTitle('Account Details'),

                    _buildTextField(
                      controller: _usernameController,
                      label: 'Username',
                      icon: Icons.person_outline,
                    ),

                    _buildTextField(
                      controller: _emailController,
                      label: 'Account Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: _emailValidator,
                    ),

                    _buildTextField(
                      controller: _phoneController,
                      label: 'Account Phone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),

                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      validator: _passwordValidator,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),

                    // Hotel Details
                    _buildSectionTitle('Hotel Details'),

                    _buildTextField(
                      controller: _hotelNameController,
                      label: 'Hotel Name',
                      icon: Icons.hotel_outlined,
                    ),

                    _buildTextField(
                      controller: _contactPersonController,
                      label: 'Contact Person',
                      icon: Icons.person_outline,
                    ),

                    _buildTextField(
                      controller: _hotelPhoneController,
                      label: 'Hotel Phone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),

                    _buildTextField(
                      controller: _hotelEmailController,
                      label: 'Hotel Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: _emailValidator,
                    ),

                    _buildTextField(
                      controller: _addressController,
                      label: 'Address',
                      icon: Icons.location_on_outlined,
                      maxLines: 3,
                    ),

                    _buildTextField(
                      controller: _cityController,
                      label: 'City',
                      icon: Icons.location_city_outlined,
                    ),

                    _buildTextField(
                      controller: _stateController,
                      label: 'State',
                      icon: Icons.map_outlined,
                    ),

                    _buildTextField(
                      controller: _pinCodeController,
                      label: 'PIN Code',
                      icon: Icons.pin_outlined,
                      keyboardType: TextInputType.number,
                    ),

                    _buildTextField(
                      controller: _gstNumberController,
                      label: 'GST Number (Optional)',
                      icon: Icons.receipt_long_outlined,
                      validator: (value) => null,
                    ),

                    _buildTextField(
                      controller: _propertyTypeController,
                      label: 'Property Type',
                      icon: Icons.apartment_outlined,
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _registerHotel,
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Register Hotel'),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },
                      child: const Text('Already registered? Sign In'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
