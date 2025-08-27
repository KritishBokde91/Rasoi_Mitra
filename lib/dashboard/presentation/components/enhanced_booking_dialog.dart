import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:rasoi_mitra2/core/utils/app_color.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:sizer/sizer.dart';
import '../../../pre_dashboard/presentation/components/location_picker_screen.dart';
import '../../domain/entities/booking_item.dart';
import '../../domain/entities/menu_item.dart';

class EnhancedBookingDialog extends StatefulWidget {
  final String mealType;
  final MenuItem item;
  final Function(BookingItem) onBookingConfirmed;
  final Razorpay razorpay;

  const EnhancedBookingDialog({
    super.key,
    required this.mealType,
    required this.item,
    required this.onBookingConfirmed,
    required this.razorpay,
  });

  @override
  State<EnhancedBookingDialog> createState() => _EnhancedBookingDialogState();
}

class _EnhancedBookingDialogState extends State<EnhancedBookingDialog>
    with TickerProviderStateMixin {
  int quantity = 1;
  String paymentMethod = 'cod';
  String selectedAddress = '';
  String resolvedAddress = '';
  String manualAddress = '';
  LatLng? selectedLocation;
  bool isLoadingLocation = false;
  late TabController _tabController;
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Color _getMealTypeColor(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return AppColor.breakfastColor;
      case 'Lunch':
        return AppColor.lunchColor;
      case 'Dinner':
        return AppColor.dinnerColor;
      default:
        return Colors.orange;
    }
  }

  Future<String?> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final url =
          '${dotenv.get('GET_ADDRESS_URL')}&lat=$lat&lon=$lng&zoom=18&addressdetails=1';
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
          address['postcode'] ?? '',
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

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoadingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      Position position = await Geolocator.getCurrentPosition();
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.location_on_rounded, color: Colors.white, size: 5.w),
              SizedBox(width: 3.w),
              Text(
                'Current location selected',
                style: TextStyle(fontSize: 10.sp),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3.w),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        isLoadingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_rounded, color: Colors.white, size: 5.w),
              SizedBox(width: 3.w),
              Text('Error: ${e.toString()}', style: TextStyle(fontSize: 10.sp)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3.w),
          ),
        ),
      );
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

  Future<void> _processBooking() async {
    if (selectedAddress.isEmpty && manualAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white, size: 5.w),
              SizedBox(width: 3.w),
              Text(
                'Please select or enter your address',
                style: TextStyle(fontSize: 10.sp),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3.w),
          ),
        ),
      );
      return;
    }

    String finalAddress = selectedAddress.isNotEmpty
        ? '$resolvedAddress ($selectedAddress)'
        : manualAddress;
    double totalAmount = widget.item.price * quantity;

    // Get current user
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please log in to place an order'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Save user information to 'users' collection
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'username': user.displayName ?? 'User',
      'email': user.email ?? 'customer@rasoimitra.com',
      'phone': user.phoneNumber ?? '9999999999',
    }, SetOptions(merge: true));

    // Create booking item
    BookingItem booking = BookingItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mealType: widget.mealType,
      item: widget.item.name,
      bookingTime: DateTime.now(),
      deliveryDate: DateTime.now().add(const Duration(days: 1)),
      status: paymentMethod == 'online' ? 'Pending' : 'Pending',
      price: totalAmount,
      quantity: quantity,
      address: finalAddress,
      paymentMethod: paymentMethod,
      latitude: selectedLocation?.latitude,
      longitude: selectedLocation?.longitude,
    );

    // Save booking to Firestore
    await FirebaseFirestore.instance.collection('bookings').add({
      'imageUrl': widget.item.imageUrl,
      'name': widget.item.name,
      'description': widget.item.description,
      'price': totalAmount,
      'status': booking.status,
      'userUID': user.uid,
      'email': user.email ?? 'customer@rasoimitra.com',
      'address': finalAddress,
      'phone': user.phoneNumber ?? '9999999999',
      'bookingTime': Timestamp.fromDate(booking.bookingTime),
      'deliveryDate': Timestamp.fromDate(booking.deliveryDate),
      'mealType': widget.mealType,
      'quantity': quantity,
      'latitude': selectedLocation?.latitude,
      'longitude': selectedLocation?.longitude,
      'paymentMethod': paymentMethod,
    });

    if (paymentMethod == 'online') {
      var options = {
        'key': 'rzp_test_1DP5mmOlF5G5ag',
        'amount': (totalAmount * 100).toInt(),
        'name': 'RasoiMitra',
        'description': '${widget.item.name} - ${widget.mealType}',
        'prefill': {
          'contact': user.phoneNumber ?? '9999999999',
          'email': user.email ?? 'customer@rasoimitra.com',
        },
        'theme': {'color': '#FF6B35'},
      };

      tempBooking = booking;
      widget.razorpay.open(options);
    } else {
      widget.onBookingConfirmed(booking);
    }

    Navigator.pop(context);
  }

  BookingItem? tempBooking;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(6.w),
              topRight: Radius.circular(6.w),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: 1.5.h),
                width: 12.w,
                height: 0.5.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.5.w),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(5.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 23.w,
                            height: 23.w,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4.w),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  spreadRadius: 0,
                                  blurRadius: 3.5.w,
                                  offset: Offset(0, 1.h),
                                ),
                              ],
                              image: DecorationImage(
                                image: NetworkImage(widget.item.imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Book ${widget.item.name}',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2D3748),
                                  ),
                                ),
                                SizedBox(height: 0.2.h),
                                Text(
                                  widget.item.description,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 1.h),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 3.w,
                                    vertical: 0.8.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getMealTypeColor(
                                      widget.mealType,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(13.sp),
                                    border: Border.all(
                                      color: _getMealTypeColor(
                                        widget.mealType,
                                      ).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    widget.mealType,
                                    style: TextStyle(
                                      color: _getMealTypeColor(widget.mealType),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade50,
                              Colors.green.shade100,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4.w),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                color: Colors.green.shade200,
                                borderRadius: BorderRadius.circular(2.w),
                              ),
                              child: Icon(
                                Icons.currency_rupee_rounded,
                                color: Colors.green.shade700,
                                size: 5.w,
                              ),
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              '${widget.item.price} per plate',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 2.5.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Quantity:',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4.w),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: quantity > 1
                                      ? () {
                                          setState(() {
                                            quantity--;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.remove_rounded),
                                  color: quantity > 1
                                      ? _getMealTypeColor(widget.mealType)
                                      : Colors.grey,
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 5.w,
                                  ),
                                  child: Text(
                                    '$quantity',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      quantity++;
                                    });
                                  },
                                  icon: const Icon(Icons.add_rounded),
                                  color: _getMealTypeColor(widget.mealType),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'Delivery Address:',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4.w),
                        ),
                        child: Column(
                          children: [
                            TabBar(
                              controller: _tabController,
                              labelColor: _getMealTypeColor(widget.mealType),
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: _getMealTypeColor(
                                widget.mealType,
                              ),
                              automaticIndicatorColorAdjustment: true,
                              tabs: [
                                Tab(
                                  icon: Icon(Icons.map, size: 20.sp),
                                  text: 'Select from Map',
                                ),
                                Tab(
                                  icon: Icon(
                                    Icons.location_on_outlined,
                                    size: 20.sp,
                                  ),
                                  text: 'Enter Address',
                                ),
                              ],
                              labelStyle: TextStyle(fontSize: 13.sp),
                              unselectedLabelStyle: TextStyle(fontSize: 13.sp),
                            ),
                            SizedBox(
                              height: 25.h,
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(4.w),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: isLoadingLocation
                                                    ? null
                                                    : _getCurrentLocation,
                                                icon: isLoadingLocation
                                                    ? SizedBox(
                                                        width: 4.w,
                                                        height: 4.w,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(Colors.white),
                                                        ),
                                                      )
                                                    : Icon(
                                                        Icons
                                                            .my_location_rounded,
                                                        size: 20.sp,
                                                      ),
                                                label: Text(
                                                  isLoadingLocation
                                                      ? 'Getting Location...'
                                                      : 'Use Current Location',
                                                  style: TextStyle(
                                                    fontSize: 13.sp,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue,
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 1.5.h,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          3.w,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 3.w),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: _navigateToMapScreen,
                                                icon: Icon(
                                                  Icons.map_outlined,
                                                  size: 20.sp,
                                                ),
                                                label: Text(
                                                  'Choose on Map',
                                                  style: TextStyle(
                                                    fontSize: 13.sp,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      _getMealTypeColor(
                                                        widget.mealType,
                                                      ),
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 1.5.h,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          3.w,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 2.h),
                                        if (selectedAddress.isNotEmpty)
                                          Container(
                                            width: double.infinity,
                                            padding: EdgeInsets.all(3.w),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(3.w),
                                              border: Border.all(
                                                color: Colors.green.shade200,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.location_on_rounded,
                                                      color:
                                                          Colors.green.shade600,
                                                      size: 20.sp,
                                                    ),
                                                    SizedBox(width: 2.w),
                                                    Expanded(
                                                      child: Text(
                                                        resolvedAddress
                                                                .isNotEmpty
                                                            ? resolvedAddress
                                                            : 'Resolving address...',
                                                        style: TextStyle(
                                                          color: Colors
                                                              .green
                                                              .shade700,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14.sp,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 1.h),
                                                Text(
                                                  selectedAddress,
                                                  style: TextStyle(
                                                    color:
                                                        Colors.green.shade600,
                                                    fontSize: 11.sp,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(4.w),
                                    child: TextField(
                                      controller: _addressController,
                                      maxLines: 4,
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
                                        hintText:
                                            'Enter your complete delivery address...',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            3.w,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            3.w,
                                          ),
                                          borderSide: BorderSide(
                                            color: _getMealTypeColor(
                                              widget.mealType,
                                            ),
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.all(4.w),
                                      ),
                                      style: TextStyle(fontSize: 10.sp),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'Payment Method:',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4.w),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.money_rounded,
                                    color: Colors.green,
                                    size: 5.w,
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    'Cash on Delivery',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'Pay when your order arrives',
                                style: TextStyle(fontSize: 12.sp),
                              ),
                              value: 'cod',
                              groupValue: paymentMethod,
                              activeColor: _getMealTypeColor(widget.mealType),
                              onChanged: (value) {
                                setState(() {
                                  paymentMethod = value!;
                                });
                              },
                            ),
                            Divider(color: Colors.grey.shade300, height: 1),
                            RadioListTile<String>(
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.payment_rounded,
                                    color: Colors.blue,
                                    size: 5.w,
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    'Online Payment',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'Pay now via UPI, Card, or Wallet',
                                style: TextStyle(fontSize: 12.sp),
                              ),
                              value: 'online',
                              groupValue: paymentMethod,
                              activeColor: _getMealTypeColor(widget.mealType),
                              onChanged: (value) {
                                setState(() {
                                  paymentMethod = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(5.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getMealTypeColor(
                                widget.mealType,
                              ).withValues(alpha: 0.1),
                              _getMealTypeColor(
                                widget.mealType,
                              ).withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4.w),
                          border: Border.all(
                            color: _getMealTypeColor(
                              widget.mealType,
                            ).withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount:',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₹${(widget.item.price * quantity).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: _getMealTypeColor(widget.mealType),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 2.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4.w),
                                ),
                                side: BorderSide(
                                  color: Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _getMealTypeColor(widget.mealType),
                                    _getMealTypeColor(
                                      widget.mealType,
                                    ).withValues(alpha: 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4.w),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getMealTypeColor(
                                      widget.mealType,
                                    ).withValues(alpha: 0.3),
                                    spreadRadius: 0,
                                    blurRadius: 3.5.w,
                                    offset: Offset(0, 1.h),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _processBooking,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.symmetric(vertical: 2.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4.w),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      paymentMethod == 'online'
                                          ? Icons.payment_rounded
                                          : Icons.shopping_bag_rounded,
                                      color: Colors.white,
                                      size: 5.w,
                                    ),
                                    SizedBox(width: 3.w),
                                    Text(
                                      paymentMethod == 'online'
                                          ? 'Pay Now'
                                          : 'Place Order',
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
