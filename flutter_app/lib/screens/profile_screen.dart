import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  final _accountFormKey = GlobalKey<FormState>();
  final _hotelFormKey = GlobalKey<FormState>();

  // Account controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleController = TextEditingController();

  // Hotel controllers
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

  bool _isLoading = true;
  bool _isSavingAccount = false;
  bool _isSavingHotel = false;

  bool _isHotelUser = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _roleController.dispose();

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

  Future<Map<String, String>> _getHeaders() async {
    final token = await _secureStorage.read(
      key: 'access_token',
    );

    if (token == null || token.isEmpty) {
      throw Exception('Please sign in again.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  dynamic _decodeResponse(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response received from the server.');
    }
  }

  String _getErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['detail'] != null) {
        return data['detail'].toString();
      }

      if (data['message'] != null) {
        return data['message'].toString();
      }

      if (data['error'] != null) {
        return data['error'].toString();
      }

      final errors = <String>[];

      data.forEach((key, value) {
        if (value is List) {
          errors.add('$key: ${value.join(', ')}');
        } else {
          errors.add('$key: $value');
        }
      });

      if (errors.isNotEmpty) {
        return errors.join('\n');
      }
    }

    return 'Something went wrong. Please try again.';
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final headers = await _getHeaders();

      final accountResponse = await http.get(
        Uri.parse(ApiConfig.currentUser),
        headers: headers,
      );

      if (accountResponse.statusCode != 200) {
        throw Exception(
          _getErrorMessage(_decodeResponse(accountResponse)),
        );
      }

      final accountData = _decodeResponse(accountResponse);

      if (accountData is! Map<String, dynamic>) {
        throw Exception('Invalid account information received.');
      }

      final role = accountData['role']?.toString() ?? '';

      _usernameController.text =
          accountData['username']?.toString() ?? '';

      _emailController.text =
          accountData['email']?.toString() ?? '';

      _phoneController.text =
          accountData['phone']?.toString() ?? '';

      _roleController.text = role;

      _isHotelUser = role == 'HOTEL';

      if (_isHotelUser) {
        final hotelResponse = await http.get(
          Uri.parse(ApiConfig.myHotel),
          headers: headers,
        );

        if (hotelResponse.statusCode != 200) {
          throw Exception(
            _getErrorMessage(_decodeResponse(hotelResponse)),
          );
        }

        final hotelData = _decodeResponse(hotelResponse);

        if (hotelData is! Map<String, dynamic>) {
          throw Exception('Invalid hotel information received.');
        }

        _hotelNameController.text =
            hotelData['name']?.toString() ?? '';

        _contactPersonController.text =
            hotelData['contact_person']?.toString() ?? '';

        _hotelPhoneController.text =
            hotelData['phone']?.toString() ?? '';

        _hotelEmailController.text =
            hotelData['email']?.toString() ?? '';

        _addressController.text =
            hotelData['address']?.toString() ?? '';

        _cityController.text =
            hotelData['city']?.toString() ?? '';

        _stateController.text =
            hotelData['state']?.toString() ?? '';

        _pinCodeController.text =
            hotelData['pin_code']?.toString() ?? '';

        _gstNumberController.text =
            hotelData['gst_number']?.toString() ?? '';

        _propertyTypeController.text =
            hotelData['property_type']?.toString() ?? '';
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAccountProfile() async {
    if (!_accountFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSavingAccount = true;
    });

    try {
      final response = await http.patch(
        Uri.parse(ApiConfig.currentUser),
        headers: await _getHeaders(),
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
        }),
      );

      final data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw Exception(_getErrorMessage(data));
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account information updated successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadProfile();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAccount = false;
        });
      }
    }
  }

  Future<void> _saveHotelProfile() async {
    if (!_hotelFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSavingHotel = true;
    });

    try {
      final response = await http.patch(
        Uri.parse(ApiConfig.myHotel),
        headers: await _getHeaders(),
        body: jsonEncode({
          'name': _hotelNameController.text.trim(),
          'contact_person': _contactPersonController.text.trim(),
          'phone': _hotelPhoneController.text.trim(),
          'email': _hotelEmailController.text.trim(),
          'address': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'pin_code': _pinCodeController.text.trim(),
          'gst_number': _gstNumberController.text.trim(),
          'property_type': _propertyTypeController.text.trim(),
        }),
      );

      final data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw Exception(_getErrorMessage(data));
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hotel information updated successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadProfile();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingHotel = false;
        });
      }
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 24,
        bottom: 16,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    bool required = true,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator ??
            (required
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter $label';
                    }
                    return null;
                  }
                : null),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          filled: readOnly,
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _accountFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle(
                'Account Information',
                Icons.person_outline,
              ),

              _buildTextField(
                controller: _usernameController,
                label: 'Username',
                icon: Icons.person,
                readOnly: true,
              ),

              _buildTextField(
                controller: _roleController,
                label: 'Account Role',
                icon: Icons.badge_outlined,
                readOnly: true,
              ),

              _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email address';
                  }

                  if (!RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(value.trim())) {
                    return 'Please enter a valid email address';
                  }

                  return null;
                },
              ),

              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 8),

              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _isSavingAccount || _isSavingHotel
                      ? null
                      : _saveAccountProfile,
                  icon: _isSavingAccount
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSavingAccount
                        ? 'Saving...'
                        : 'Update Account',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHotelSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _hotelFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle(
                'Hotel Information',
                Icons.hotel_outlined,
              ),

              _buildTextField(
                controller: _hotelNameController,
                label: 'Hotel Name',
                icon: Icons.hotel,
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter hotel email';
                  }

                  if (!RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(value.trim())) {
                    return 'Please enter a valid email address';
                  }

                  return null;
                },
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
                label: 'GST Number',
                icon: Icons.receipt_long_outlined,
                required: false,
              ),

              _buildTextField(
                controller: _propertyTypeController,
                label: 'Property Type',
                icon: Icons.apartment_outlined,
              ),

              const SizedBox(height: 8),

              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _isSavingHotel || _isSavingAccount
                      ? null
                      : _saveHotelProfile,
                  icon: _isSavingHotel
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSavingHotel
                        ? 'Saving...'
                        : 'Update Hotel Information',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: _isLoading ? null : _loadProfile,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadProfile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 600,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),

                            CircleAvatar(
                              radius: 42,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.account_circle_outlined,
                                size: 58,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              _usernameController.text,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),

                            Text(
                              _roleController.text,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),

                            _buildAccountSection(),

                            if (_isHotelUser) _buildHotelSection(),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}