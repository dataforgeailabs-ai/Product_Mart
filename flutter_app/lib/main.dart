import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'config/api_config.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/delivery_dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/hotel_registration_screen.dart';
import 'widgets/brand_logo.dart';

const FlutterSecureStorage secureStorage = FlutterSecureStorage();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MistyGoApp());
}

class MistyGoApp extends StatelessWidget {
  const MistyGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Misty Go Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC41E34),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFFC41E34),
          onPrimary: Colors.white,
          secondary: const Color(0xFFF0505F),
          surface: const Color(0xFFFFFBFB),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFBFB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFC41E34),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFC41E34), width: 2),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 1,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC41E34),
            foregroundColor: Colors.white,
          ),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final loginResponse = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      dynamic loginData;

      try {
        loginData = jsonDecode(loginResponse.body);
      } catch (_) {
        throw Exception(
          'The server returned an invalid login response.',
        );
      }

      if (loginData is! Map<String, dynamic>) {
        throw Exception(
          'Unexpected response from the server.',
        );
      }

      if (loginResponse.statusCode != 200) {
        final message = loginData['detail'] ??
            loginData['non_field_errors']?.toString() ??
            'Login failed. Please check your credentials.';

        throw Exception(message.toString());
      }

      final accessToken = loginData['access']?.toString();
      final refreshToken = loginData['refresh']?.toString();

      if (accessToken == null ||
          accessToken.isEmpty ||
          refreshToken == null ||
          refreshToken.isEmpty) {
        throw Exception(
          'The server did not return both JWT tokens.',
        );
      }

      await secureStorage.write(
        key: 'access_token',
        value: accessToken,
      );

      await secureStorage.write(
        key: 'refresh_token',
        value: refreshToken,
      );

      // Verify the authenticated user's role using the backend.
      final profileResponse = await http.get(
        Uri.parse(ApiConfig.currentUser),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (profileResponse.statusCode != 200) {
        await secureStorage.delete(key: 'access_token');
        await secureStorage.delete(key: 'refresh_token');

        throw Exception(
          'Unable to verify your account role. '
          'Please try signing in again.',
        );
      }

      final dynamic profileData =
          jsonDecode(profileResponse.body);

      if (profileData is! Map<String, dynamic>) {
        await secureStorage.delete(key: 'access_token');
        await secureStorage.delete(key: 'refresh_token');

        throw Exception(
          'Invalid user profile returned by the server.',
        );
      }

      final role = profileData['role']?.toString();
      final isActive = profileData['is_active'] == true;

      if (!isActive) {
        await secureStorage.delete(key: 'access_token');
        await secureStorage.delete(key: 'refresh_token');

        throw Exception(
          'Your account is inactive. Please contact support.',
        );
      }

      if (!mounted) return;

      Widget destination;

      switch (role) {
        case 'SUPERADMIN':
        case 'ADMIN':
          destination = const AdminDashboardScreen();
          break;

        case 'DELIVERY':
          destination = const DeliveryDashboardScreen();
          break;

        case 'HOTEL':
          destination = const HomeScreen();
          break;

        default:
          await secureStorage.delete(key: 'access_token');
          await secureStorage.delete(key: 'refresh_token');

          throw Exception(
            'Your account has an unsupported role. '
            'Please contact support.',
          );
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => destination,
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().startsWith('Exception: ')
          ? e.toString().substring('Exception: '.length)
          : e.toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BrandLogo(height: 92),

                    const SizedBox(height: 20),

                    Text(
                      'Misty Go Delivery',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),

                    const SizedBox(height: 32),

                    // Username
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(
                          Icons.person_outline,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your username';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                        ),
                        border: const OutlineInputBorder(),
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Sign In Button
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Sign In'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Hotel Registration Button
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const HotelRegistrationScreen(),
                                ),
                              );
                            },
                      icon: const Icon(Icons.hotel_outlined),
                      label: const Text('Register Your Hotel'),
                    ),

                    const SizedBox(height: 12),

                    // Continue Browsing
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Continue browsing'),
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
