import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../pre_dashboard/presentation/components/location_picker_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLocationLoading = false;

  String _email = '';
  double _locationLat = 0.0;
  double _locationLng = 0.0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) return;

    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _email = userData['email'] ?? '';
          _usernameController.text = userData['username'] ?? '';
          _phoneController.text = userData['phone'] ?? '';
          _locationController.text = userData['location_address'] ?? '';
          _locationLat = userData['location_lat']?.toDouble() ?? 0.0;
          _locationLng = userData['location_lng']?.toDouble() ?? 0.0;
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load profile data');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permission denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      String address = await _getAddressFromLatLng(position.latitude, position.longitude);

      setState(() {
        _locationLat = position.latitude;
        _locationLng = position.longitude;
        _locationController.text = address;
        _isLocationLoading = false;
      });

      _showSuccessSnackBar('Location updated successfully');
    } catch (e) {
      setState(() => _isLocationLoading = false);
      _showErrorSnackBar('Failed to get current location: ${e.toString()}');
    }
  }

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'RasoiMitraApp/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];

        // Extract relevant components
        final locality = address['suburb'] ?? address['neighbourhood'] ?? address['road'] ?? '';
        final city = address['city'] ?? address['town'] ?? address['village'] ?? '';
        final postalCode = address['postcode'] ?? '';

        // Construct the desired format: "Locality, City PostalCode"
        final parts = [
          if (locality.isNotEmpty) locality,
          if (city.isNotEmpty) city,
        ].join(', ');
        final formattedAddress = postalCode.isNotEmpty ? '$parts $postalCode' : parts;

        return formattedAddress.isNotEmpty ? formattedAddress : data['display_name'] ?? 'Current Location, City 440002';
      } else {
        return 'Current Location, City 440002';
      }
    } catch (e) {
      return 'Current Location, City 440002';
    }
  }

  Future<void> _openLocationPicker() async {
    if (_locationLat == 0.0 && _locationLng == 0.0) {
      // If no location is set, use a default location (like Nagpur center)
      _locationLat = 21.1458;
      _locationLng = 79.0882;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialPosition: LatLng(_locationLat, _locationLng),
        ),
      ),
    );

    if (result != null) {
      LatLng location = result['location'];
      String address = result['address'];

      setState(() {
        _locationLat = location.latitude;
        _locationLng = location.longitude;
        _locationController.text = address;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'username': _usernameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location_address': _locationController.text.trim(),
        'location_lat': _locationLat,
        'location_lng': _locationLng,
      });

      _showSuccessSnackBar('Profile updated successfully');
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      _showErrorSnackBar('Failed to update profile');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
              ),
              SizedBox(height: 20),
              Text(
                'Loading profile...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          _buildFormSection(),
                          SizedBox(height: 30),
                          _buildSaveButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepOrange, Colors.orange.shade400],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: Colors.white, size: 24),
          ),
          Expanded(
            child: Text(
              'Edit Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepOrange.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.orange.shade50,
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.deepOrange,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Text(
            'Update Profile Picture',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 20),

        // Email (Read-only)
        _buildReadOnlyField(
          label: 'Email Address',
          value: _email,
          icon: Icons.email_outlined,
        ),
        SizedBox(height: 20),

        // Username
        _buildInputField(
          controller: _usernameController,
          label: 'Username',
          icon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your username';
            }
            if (value.trim().length < 2) {
              return 'Username must be at least 2 characters';
            }
            return null;
          },
        ),
        SizedBox(height: 20),

        // Phone
        _buildInputField(
          controller: _phoneController,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your phone number';
            }
            if (value.trim().length != 10) {
              return 'Please enter a valid 10-digit phone number';
            }
            return null;
          },
        ),
        SizedBox(height: 20),

        // Location
        _buildLocationField(),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey[500], size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Icon(Icons.lock_outline, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.deepOrange),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.deepOrange, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            color: Colors.white,
          ),
          child: Column(
            children: [
              TextFormField(
                controller: _locationController,
                readOnly: true,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined, color: Colors.deepOrange),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  hintText: 'Select your location',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please select your location';
                  }
                  return null;
                },
              ),
              Container(
                height: 1,
                color: Colors.grey[200],
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _isLocationLoading ? null : _getCurrentLocation,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: _isLocationLoading
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Getting...',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.my_location, color: Colors.deepOrange, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Current Location',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[200]),
                  Expanded(
                    child: InkWell(
                      onTap: _openLocationPicker,
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(12),
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_outlined, color: Colors.deepOrange, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Pick from Map',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepOrange, Colors.orange.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.4),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isSaving ? null : _saveProfile,
          child: Center(
            child: _isSaving
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Saving...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
                : Text(
              'Save Changes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}