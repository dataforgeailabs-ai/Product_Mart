import 'package:flutter/material.dart';

import '../models/managed_user.dart';
import '../services/user_service.dart';

class AdminUserFormScreen extends StatefulWidget {
  final ManagedUser? user;

  const AdminUserFormScreen({
    super.key,
    this.user,
  });

  @override
  State<AdminUserFormScreen> createState() =>
      _AdminUserFormScreenState();
}

class _AdminUserFormScreenState
    extends State<AdminUserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isProfileLoading = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _selectedRole;
  List<String> _availableRoles = [];

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      _usernameController.text = widget.user!.username;
      _emailController.text = widget.user!.email;
      _phoneController.text = widget.user!.phone;
      _selectedRole = widget.user!.role;
      _isProfileLoading = false;
    } else {
      _loadCurrentUser();
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final profile = await _userService.getCurrentUser();

      final role = profile['role']?.toString();

      if (role == 'SUPERADMIN') {
        _availableRoles = ['ADMIN', 'DELIVERY'];
      } else if (role == 'ADMIN') {
        _availableRoles = ['DELIVERY'];
      } else {
        throw Exception(
          'You are not authorized to create users.',
        );
      }

      if (!mounted) return;

      setState(() {
        _selectedRole = _availableRoles.first;
        _isProfileLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProfileLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? _validateRequired(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $label';
    }

    return null;
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isEditing && _selectedRole == null) return;

    final password = _passwordController.text;

    if (!_isEditing && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password is required.'),
        ),
      );
      return;
    }

    if (password.isNotEmpty) {
      if (password.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password must contain at least 8 characters.',
            ),
          ),
        );
        return;
      }

      if (password != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isEditing) {
        await _userService.updateUser(
          userId: widget.user!.id,
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: password.isEmpty ? null : password,
        );
      } else {
        await _userService.createUser(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: password,
          role: _selectedRole!,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'User updated successfully.'
                : 'User created successfully.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
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
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
      validator: (value) {
        if (required) {
          return _validateRequired(value, label.toLowerCase());
        }

        return null;
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit User' : 'Add User'),
      ),
      body: _isProfileLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _availableRoles.isEmpty && !_isEditing
              ? const Center(
                  child: Text(
                    'You are not authorized to manage users.',
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_isEditing) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            decoration: const InputDecoration(
                              labelText: 'Select Role',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            items: _availableRoles.map((role) {
                              return DropdownMenuItem<String>(
                                value: role,
                                child: Text(
                                  role == 'ADMIN'
                                      ? 'Admin'
                                      : 'Delivery Person',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedRole = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a role';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                        ],

                        _buildTextField(
                          label: 'Username',
                          controller: _usernameController,
                          icon: Icons.person_outline,
                        ),

                        const SizedBox(height: 18),

                        _buildTextField(
                          label: 'Email',
                          controller: _emailController,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 18),

                        _buildTextField(
                          label: 'Phone',
                          controller: _phoneController,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          required: false,
                        ),

                        const SizedBox(height: 18),

                        _buildTextField(
                          label: _isEditing
                              ? 'New Password (optional)'
                              : 'Password',
                          controller: _passwordController,
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          required: !_isEditing,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),

                        const SizedBox(height: 18),

                        _buildTextField(
                          label: 'Confirm Password',
                          controller: _confirmPasswordController,
                          icon: Icons.lock_reset_outlined,
                          obscureText: _obscureConfirmPassword,
                          required: !_isEditing,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),

                        const SizedBox(height: 28),

                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : _saveUser,
                            icon: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _isLoading
                                  ? 'Saving...'
                                  : _isEditing
                                      ? 'Update User'
                                      : 'Create User',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}