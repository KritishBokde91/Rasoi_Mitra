import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rasoi_mitra2/dashboard/presentation/pages/home_screen.dart';
import 'package:sizer/sizer.dart';
import 'dart:convert';
import '../../../dashboard/presentation/pages/dashboard_screen.dart';
import '../components/location_picker_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isCheckingUsername = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isFetchingLocation = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Step 1 Controllers and Variables
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  LatLng? _selectedLocation;
  String? _selectedAddress;

  // Step 2 Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  // Geolocator for user's current location
  LatLng? _initialPosition;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _getCurrentLocation();
    _animationController.forward();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isFetchingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showErrorSnackBar('Location services are disabled. Using default location.');
          setState(() {
            _initialPosition = const LatLng(21.1458, 79.0882); // Nagpur coordinates
            _selectedLocation = _initialPosition;
            _selectedAddress = 'Nagpur, Maharashtra - 440008';
            _isFetchingLocation = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showErrorSnackBar('Location permissions denied. Using default location.');
            setState(() {
              _initialPosition = const LatLng(21.1458, 79.0882);
              _selectedLocation = _initialPosition;
              _selectedAddress = 'Nagpur, Maharashtra - 440008';
              _isFetchingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showErrorSnackBar('Location permissions permanently denied. Using default location.');
          setState(() {
            _initialPosition = const LatLng(21.1458, 79.0882);
            _selectedLocation = _initialPosition;
            _selectedAddress = 'Nagpur, Maharashtra - 440008';
            _isFetchingLocation = false;
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        String? address = await _getAddressFromLatLng(position.latitude, position.longitude);
        setState(() {
          _initialPosition = LatLng(position.latitude, position.longitude);
          _selectedLocation = _initialPosition;
          _selectedAddress = address ?? 'Nagpur, Maharashtra - 440008';
          _isFetchingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to get location: $e. Using default location.');
        setState(() {
          _initialPosition = const LatLng(21.1458, 79.0882);
          _selectedLocation = _initialPosition;
          _selectedAddress = 'Nagpur, Maharashtra - 440008';
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<String?> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'RasoiMitraApp/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];
        final locality = address['suburb'] ?? address['neighbourhood'] ?? address['road'] ?? '';
        final city = address['city'] ?? address['town'] ?? address['village'] ?? '';
        final postalCode = address['postcode'] ?? '';
        final parts = [
          if (locality.isNotEmpty) locality,
          if (city.isNotEmpty) city,
        ].join(', ');
        final formattedAddress = postalCode.isNotEmpty ? '$parts - $postalCode' : parts;
        return formattedAddress.isNotEmpty ? formattedAddress : data['display_name'] ?? 'Unknown address';
      } else {
        return 'Unknown address';
      }
    } catch (e) {
      debugPrint('Error fetching address: $e');
      return 'Unknown address';
    }
  }

  Future<void> _pickLocation() async {
    if (_isFetchingLocation) {
      _showErrorSnackBar('Still fetching initial location. Please wait.');
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialPosition: _initialPosition ?? const LatLng(21.1458, 79.0882),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result['location'] as LatLng;
        _selectedAddress = result['address'] as String;
      });
    }
  }

  Future<bool> _isUsernameUnique(String username) async {
    setState(() {
      _isCheckingUsername = true;
    });
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();
      return query.docs.isEmpty;
    } catch (e) {
      debugPrint('Error checking username: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
        });
      }
    }
  }

  Future<void> _signup() async {
    if (_step2FormKey.currentState!.validate()) {
      if (_selectedLocation == null || _selectedAddress == null) {
        _showErrorSnackBar('Please select a valid location.');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final username = _usernameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final lat = _selectedLocation!.latitude;
      final lng = _selectedLocation!.longitude;
      final address = _selectedAddress!;

      try {
        final isUnique = await _isUsernameUnique(username);
        if (!isUnique) {
          throw Exception('username-exists');
        }

        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'username': username,
          'phone': phone,
          'email': email,
          'location_lat': lat,
          'location_lng': lng,
          'location_address': address,
          'created_at': Timestamp.now(),
        });

        if (mounted) {
          _showSuccessSnackBar('Account created successfully!');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
          );
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          _showErrorSnackBar(_getAuthErrorMessage(e.code));
        }
      } on Exception catch (e) {
        if (mounted) {
          _showErrorSnackBar(_getCustomErrorMessage(e.toString()));
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('An unexpected error occurred: $e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password is too weak. Please choose a stronger password.';
      case 'email-already-in-use':
        return 'This email is already in use. Please try another email.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Contact support.';
      default:
        return 'Signup failed. Please try again.';
    }
  }

  String _getCustomErrorMessage(String error) {
    if (error.contains('username-exists')) {
      return 'Username already exists. Please choose another.';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isFetchingLocation
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitThreeBounce(
                color: Color(0xFFFF6B35),
                size: 30.0,
              ),
              SizedBox(height: 24),
              Text(
                'Setting up your location...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
            : FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          margin: const EdgeInsets.only(bottom: 32),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFF6B35),
                                Color(0xFFFF8E53),
                                Color(0xFFFFAD71),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B35).withOpacity(0.3),
                                spreadRadius: 0,
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Column(
                            children: [
                              Text(
                                '🍽️',
                                style: TextStyle(fontSize: 40),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'RasoiMitra',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Join our culinary community',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Progress Indicator
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: _currentStep >= 0 ? const Color(0xFFFF6B35) : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: _currentStep >= 1 ? const Color(0xFFFF6B35) : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Step Content
                        if (_currentStep == 0) _buildStep1(),
                        if (_currentStep == 1) _buildStep2(),

                        const SizedBox(height: 32),

                        // Action Buttons
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us about yourself',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Username Field
            _buildTextField(
              controller: _usernameController,
              label: 'Username',
              icon: Icons.person,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a username';
                }
                if (value.length < 3) {
                  return 'Username must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Phone Field
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                  return 'Please enter a valid 10-digit phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Location Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF6B35).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFFFF6B35),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isFetchingLocation ? null : _pickLocation,
                      icon: const Icon(Icons.map, color: Colors.white, size: 20),
                      label: Text(
                        _selectedLocation == null ? 'Pick Your Location' : 'Change Location',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                    ),
                  ),
                  if (_selectedAddress != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_pin,
                            color: Color(0xFFFF6B35),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedAddress!,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account Security',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your login credentials',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Email Field
            _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Password Field
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFFFF6B35),
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Confirm Password Field
            _buildTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.lock_outline,
              obscureText: _obscureConfirmPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFFFF6B35),
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      enabled: !_isCheckingUsername && !_isLoading,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFFF6B35)),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Main Action Button
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withOpacity(0.3),
                  spreadRadius: 0,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: (_isLoading || _isCheckingUsername)
                  ? null
                  : () async {
                if (_currentStep == 0) {
                  if (_step1FormKey.currentState!.validate()) {
                    setState(() {
                      _isCheckingUsername = true;
                    });
                    final isUnique = await _isUsernameUnique(_usernameController.text.trim());
                    setState(() {
                      _isCheckingUsername = false;
                    });
                    if (!isUnique) {
                      _showErrorSnackBar('Username already exists. Please choose another.');
                      return;
                    }
                    if (_selectedLocation == null) {
                      _showErrorSnackBar('Please pick a location to continue');
                      return;
                    }
                    setState(() {
                      _currentStep++;
                    });
                  }
                } else {
                  _signup();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: (_isLoading && _currentStep == 1) || _isCheckingUsername
                  ? const SpinKitThreeBounce(
                color: Colors.white,
                size: 24.0,
              )
                  : Text(
                _currentStep == 0 ? 'Continue to Account Setup' : 'Create Account',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Secondary Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              if (_currentStep > 0) {
                setState(() {
                  _currentStep--;
                });
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: const BorderSide(color: Color(0xFFFF6B35)),
            ),
            child: Text(
              _currentStep == 0 ? 'Back to Login' : 'Previous Step',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF6B35),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}