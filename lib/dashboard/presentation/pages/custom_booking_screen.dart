import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:rasoi_mitra2/core/utils/app_color.dart';
import 'package:sizer/sizer.dart';
import 'dart:convert';
import '../../../pre_dashboard/presentation/components/location_picker_screen.dart';
import '../../domain/entities/booking_item.dart';

class CustomBookingScreen extends StatefulWidget {
  const CustomBookingScreen({super.key});

  @override
  State<CustomBookingScreen> createState() => _CustomBookingScreenState();
}

class _CustomBookingScreenState extends State<CustomBookingScreen>
    with TickerProviderStateMixin {
  final TextEditingController _peopleController = TextEditingController();
  final TextEditingController _menuController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String selectedMealType = 'Lunch';
  bool _isLoading = false;
  String selectedAddress = '';
  String resolvedAddress = '';
  String manualAddress = '';
  LatLng? selectedLocation;
  bool isLoadingLocation = false;
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _peopleController.dispose();
    _menuController.dispose();
    _addressController.dispose();
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final address = await _getAddressFromLatLng(
        position.latitude,
        position.longitude,
      );
      setState(() {
        selectedLocation = LatLng(position.latitude, position.longitude);
        selectedAddress =
        'Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
        resolvedAddress = address ?? 'Unknown address';
        isLoadingLocation = false;
      });

      _showSuccessSnackBar('Current location selected');
    } catch (e) {
      setState(() {
        isLoadingLocation = false;
      });
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<String?> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1';
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'RasoiMitraApp/1.0'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];
        final parts = [
          address['road'] ?? '',
          address['suburb'] ?? '',
          address['city'] ?? address['town'] ?? address['village'] ?? '',
        ].where((part) => part.isNotEmpty).join(', ');
        return parts.isNotEmpty
            ? parts
            : data['display_name'] ?? 'Unknown address';
      } else {
        return 'Unable to fetch address';
      }
    } catch (e) {
      return 'Address unavailable';
    }
  }

  void _navigateToMapScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialPosition: selectedLocation ?? const LatLng(21.1458, 79.0882),
        ),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        selectedLocation = result['location'] as LatLng;
        selectedAddress =
        'Selected Location (${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)})';
        resolvedAddress = result['address'] as String;
        manualAddress = '';
        _addressController.clear();
      });
    }
  }

  Future<void> _handleCustomBooking() async {
    String people = _peopleController.text.trim();
    String menu = _menuController.text.trim();

    if (people.isEmpty || menu.isEmpty) {
      _showErrorSnackBar('Please fill all fields');
      return;
    }

    int numberOfPeople = int.tryParse(people) ?? 0;

    if (numberOfPeople < 15) {
      _showErrorSnackBar('Minimum 15 people required for custom booking');
      return;
    }

    if (selectedAddress.isEmpty && manualAddress.isEmpty) {
      _showErrorSnackBar('Please select or enter your address');
      return;
    }

    String finalAddress = selectedAddress.isNotEmpty
        ? '$resolvedAddress ($selectedAddress)'
        : manualAddress;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar('You must be logged in to place a booking');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) {
        _showErrorSnackBar(
          'User profile not found. Please complete your profile.',
        );
        return;
      }

      final userData = userDoc.data()!;
      final username = userData['username'] as String? ?? 'Unknown';
      final userEmail = userData['email'] as String? ?? user.email!;
      final phone = userData['phone'] as String? ?? 'Unknown';

      final customBooking = BookingItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        mealType: selectedMealType,
        item: 'Custom Menu: $menu',
        bookingTime: DateTime.now(),
        deliveryDate: DateTime.now().add(const Duration(days: 1)),
        status: 'Pending',
        price: 0.0,
        quantity: numberOfPeople,
        isCustom: true,
        address: finalAddress,
        paymentMethod: '',
        latitude: selectedLocation?.latitude,
        longitude: selectedLocation?.longitude,
      );

      await FirebaseFirestore.instance
          .collection('custom_bookings')
          .doc(customBooking.id)
          .set({
        'id': customBooking.id,
        'mealType': customBooking.mealType,
        'item': customBooking.item,
        'bookingTime': Timestamp.fromDate(customBooking.bookingTime),
        'deliveryDate': Timestamp.fromDate(customBooking.deliveryDate),
        'status': customBooking.status,
        'quantity': customBooking.quantity,
        'isCustom': customBooking.isCustom,
        'address': customBooking.address,
        'paymentMethod': customBooking.paymentMethod,
        'username': username,
        'user_email': userEmail,
        'phone': phone,
        'latitude': customBooking.latitude,
        'longitude': customBooking.longitude,
        'userUID': user.uid,
      });

      _showSuccessSnackBar('Our team will contact you soon');

      if (mounted) {
        _showBookingSuccessDialog(numberOfPeople, menu, selectedMealType, finalAddress, userEmail, phone);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to place booking: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showBookingSuccessDialog(int numberOfPeople, String menu, String mealType, String address, String email, String phone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 16,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFFFF8F5)],
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(6.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success Icon Animation
                    Container(
                      width: 20.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 12.w,
                      ),
                    ),
                    SizedBox(height: 3.h),

                    // Title
                    Text(
                      'Booking Confirmed!',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D3748),
                      ),
                    ),
                    SizedBox(height: 2.h),

                    Text(
                      'Your custom booking has been placed successfully!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 3.h),

                    // Booking Details Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F5),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          _buildDialogDetailRow(Icons.people, 'People', '$numberOfPeople'),
                          _buildDialogDetailRow(Icons.restaurant_menu, 'Menu', menu),
                          _buildDialogDetailRow(Icons.schedule, 'Meal Type', mealType),
                          _buildDialogDetailRow(Icons.location_on, 'Address', address),
                          _buildDialogDetailRow(Icons.email, 'Email', email),
                          _buildDialogDetailRow(Icons.phone, 'Phone', phone),
                        ],
                      ),
                    ),
                    SizedBox(height: 3.h),

                    // Contact Message
                    Container(
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF6B35).withOpacity(0.1),
                            const Color(0xFFFFAD71).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.support_agent,
                            color: const Color(0xFFFF6B35),
                            size: 6.w,
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: Text(
                              'Our team will contact you within 24 hours to finalize the details',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFFF6B35),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 4.h),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          padding: EdgeInsets.symmetric(vertical: 3.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFFFF6B35).withOpacity(0.4),
                        ),
                        child: Text(
                          'Got it!',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFFFF6B35),
            size: 4.w,
          ),
          SizedBox(width: 3.w),
          SizedBox(
            width: 20.w,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D3748),
              ),
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 1.h),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, color: Colors.white),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: EdgeInsets.all(4.w),
        duration: const Duration(seconds: 4),
        elevation: 8,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 1.h),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.white),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: EdgeInsets.all(4.w),
        duration: const Duration(seconds: 3),
        elevation: 8,
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            children: [
              // Tab Header with Gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFFAD71)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelStyle: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map, size: 18.sp),
                          SizedBox(width: 2.w),
                          const Text('Map Location'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_location_alt, size: 18.sp),
                          SizedBox(width: 2.w),
                          const Text('Manual Address'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Content
              SizedBox(
                height: 30.h,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Map Tab
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildLocationButton(
                                  onPressed: isLoadingLocation ? null : _getCurrentLocation,
                                  icon: isLoadingLocation
                                      ? SizedBox(
                                    width: 4.w,
                                    height: 4.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                      : const Icon(Icons.my_location_rounded, size: 20),
                                  label: isLoadingLocation ? 'Getting Location...' : 'Current Location',
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                                  ),
                                ),
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: _buildLocationButton(
                                  onPressed: _navigateToMapScreen,
                                  icon: const Icon(Icons.map_outlined, size: 20),
                                  label: 'Choose on Map',
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF6B35), Color(0xFFFFAD71)],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3.h),
                          if (selectedAddress.isNotEmpty)
                            _buildSelectedLocationCard(),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(5.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter Delivery Address',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: manualAddress.isNotEmpty
                                      ? const Color(0xFFFF6B35)
                                      : Colors.grey.shade300,
                                  width: manualAddress.isNotEmpty ? 2 : 1,
                                ),
                                color: Colors.grey.shade50,
                              ),
                              child: TextField(
                                controller: _addressController,
                                maxLines: null,
                                enabled: !_isLoading,
                                onChanged: (value) {
                                  setState(() {
                                    manualAddress = value;
                                    if (value.isNotEmpty) {
                                      selectedAddress = '';
                                      resolvedAddress = '';
                                      selectedLocation = null;
                                    }
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Enter your complete delivery address with landmarks...',
                                  hintStyle: TextStyle(color: Colors.grey[500]),
                                  border: InputBorder.none,
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6B35).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.location_city,
                                      color: const Color(0xFFFF6B35),
                                      size: 20.sp,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.all(4.w),
                                ),
                                style: TextStyle(fontSize: 13.sp),
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
      ),
    );
  }

  Widget _buildLocationButton({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    required LinearGradient gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 2.5.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            SizedBox(height: 1.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedLocationCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade50,
            Colors.green.shade100.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.6.h),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: Colors.green.shade700,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Location',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                      ),
                    ),
                    Text(
                      resolvedAddress.isNotEmpty ? resolvedAddress : 'Resolving address...',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: Colors.green.shade200.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              selectedAddress,
              style: TextStyle(
                color: Colors.green.shade600,
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return _buildCustomCard(
      child: Container(
        padding: EdgeInsets.all(1.w),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          enabled: !_isLoading,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: labelText,
            labelStyle: TextStyle(
              color: Colors.grey[600],
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15.sp),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: Color(0xFFFF6B35),
                width: 2,
              ),
            ),
            prefixIcon: Container(
              margin: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFFF6B35),
                size: 20.sp,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4.w,
              vertical: 3.h,
            ),
            fillColor: Colors.white,
            filled: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 15.h,
            toolbarHeight: kToolbarHeight + 2.h,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6B35), Color(0xFFFFAD71)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -10.w,
                      top: -5.h,
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -5.w,
                      bottom: -10.h,
                      child: Container(
                        width: 30.w,
                        height: 30.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              title: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Booking',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20.sp,
                      ),
                    ),
                    Text(
                      'Create your perfect meal',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              centerTitle: false,
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: Colors.orange.withValues(alpha: 0.9),
          ),

          // Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header
                    _buildCustomCard(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFF6B35).withOpacity(0.1),
                              const Color(0xFFFFAD71).withOpacity(0.05),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(3.w),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B35),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF6B35).withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.restaurant_menu,
                                    color: Colors.white,
                                    size: 6.w,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Create Your Custom Menu',
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2D3748),
                                        ),
                                      ),
                                      SizedBox(height: 1.h),
                                      Text(
                                        'Design a personalized dining experience for your group',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 3.h),
                            Container(
                              padding: EdgeInsets.all(3.w),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.amber.shade700,
                                    size: 5.w,
                                  ),
                                  SizedBox(width: 3.w),
                                  Expanded(
                                    child: Text(
                                      'Minimum 15 people required for custom bookings',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.amber.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),

                    // Number of People Input
                    _buildAnimatedTextField(
                      controller: _peopleController,
                      labelText: 'Number of People',
                      hintText: 'Minimum 15 people required',
                      icon: Icons.people,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 3.h),

                    // Meal Type Selection
                    _buildCustomCard(
                      child: Container(
                        padding: EdgeInsets.all(1.w),
                        child: DropdownButtonFormField<String>(
                          value: selectedMealType,
                          dropdownColor: AppColor.white,
                          decoration: InputDecoration(
                            labelText: 'Meal Type',
                            labelStyle: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                color: Color(0xFFFF6B35),
                                width: 2,
                              ),
                            ),
                            prefixIcon: Container(
                              margin: EdgeInsets.all(3.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B35).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.schedule,
                                color: const Color(0xFFFF6B35),
                                size: 20.sp,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4.w,
                              vertical: 3.h,
                            ),
                            fillColor: Colors.white,
                            filled: true,
                          ),
                          items: [
                            {'value': 'Breakfast', 'icon': Icons.free_breakfast},
                            {'value': 'Lunch', 'icon': Icons.lunch_dining},
                            {'value': 'Dinner', 'icon': Icons.dinner_dining},
                          ].map((Map<String, dynamic> item) {
                            return DropdownMenuItem<String>(
                              value: item['value'],
                              child: Row(
                                children: [
                                  Icon(
                                    item['icon'],
                                    color: const Color(0xFFFF6B35),
                                    size: 18.sp,
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    item['value'],
                                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: _isLoading
                              ? null
                              : (String? newValue) {
                            setState(() {
                              selectedMealType = newValue!;
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 3.h),

                    // Custom Menu Description
                    _buildAnimatedTextField(
                      controller: _menuController,
                      labelText: 'Custom Menu Description',
                      hintText: 'Describe your ideal menu: cuisines, dietary preferences, special requirements...',
                      icon: Icons.menu_book,
                      maxLines: 4,
                    ),
                    SizedBox(height: 4.h),

                    // Location Section
                    _buildLocationSection(),
                    SizedBox(height: 5.h),

                    // Place Booking Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFFAD71)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleCustomBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isLoading
                            ? SpinKitThreeBounce(
                          color: Colors.white,
                          size: 6.w,
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant,
                              color: Colors.white,
                              size: 6.w,
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              'Place Custom Booking',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}