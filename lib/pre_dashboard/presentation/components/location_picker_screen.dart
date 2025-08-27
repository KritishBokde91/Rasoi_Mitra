import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng initialPosition;

  const LocationPickerScreen({
    super.key,
    required this.initialPosition,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng _currentPosition = const LatLng(0, 0);
  String _currentAddress = 'Loading address...';
  bool _isLoadingAddress = true;
  DateTime? _lastAddressUpdate;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition;
    _updateAddress(_currentPosition.latitude, _currentPosition.longitude);
  }

  Future<void> _updateAddress(double lat, double lng) async {
    final now = DateTime.now();
    if (_lastAddressUpdate != null && now.difference(_lastAddressUpdate!).inSeconds < 2) {
      return; // Throttle to avoid too many requests
    }
    _lastAddressUpdate = now;

    setState(() {
      _isLoadingAddress = true;
    });

    final address = await _getAddressFromLatLng(lat, lng);
    if (mounted) {
      setState(() {
        _currentAddress = address ?? 'Unknown address';
        _isLoadingAddress = false;
      });
    }
  }

  Future<String?> _getAddressFromLatLng(double lat, double lng) async {
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

        // Construct the desired format: "Locality, City - PostalCode"
        final parts = [
          if (locality.isNotEmpty) locality,
          if (city.isNotEmpty) city,
        ].join(', ');
        final formattedAddress = postalCode.isNotEmpty ? '$parts - $postalCode' : parts;

        return formattedAddress.isNotEmpty ? formattedAddress : data['display_name'] ?? 'Unknown address';
      } else {
        return 'Unable to fetch address';
      }
    } catch (e) {
      return 'Address unavailable';
    }
  }

  void _confirmLocation() {
    Navigator.pop(context, {
      'location': _currentPosition,
      'address': _currentAddress,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Pick Your Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoadingAddress ? null : _confirmLocation,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(5.w),
                      ),
                      child: Text(
                        'Confirm',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Map Container
            Expanded(
              child: _currentPosition.latitude == 0 && _currentPosition.longitude == 0
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SpinKitThreeBounce(
                      color: const Color(0xFFFF6B35),
                      size: 20.sp,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Loading map...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              )
                  : Stack(
                children: [
                  // Map
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(5.w),
                      topRight: Radius.circular(5.w),
                    ),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentPosition,
                        initialZoom: 15.0,
                        minZoom: 3.0,
                        maxZoom: 18.0,
                        onPositionChanged: (position, hasGesture) {
                          if (hasGesture) {
                            setState(() {
                              _currentPosition = position.center;
                            });
                            _updateAddress(position.center.latitude, position.center.longitude);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.rasoi.mitra',
                          maxZoom: 18,
                          additionalOptions: const {
                            'attribution': '© OpenStreetMap contributors © CARTO',
                          },
                          fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          errorImage: const NetworkImage(
                              'https://via.placeholder.com/256x256.png?text=Map+Error'),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentPosition,
                              width: 12.w,
                              height: 12.w,
                              child: Icon(
                                Icons.location_on,
                                color: Color(0xFFFF6B35),
                                size: 10.w,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Center crosshair
                  Center(
                    child: Icon(
                      Icons.add,
                      color: const Color(0xFFFF6B35),
                      size: 8.w,
                    ),
                  ),

                  // Control Buttons
                  Positioned(
                    right: 4.w,
                    top: 4.w,
                    child: Column(
                      children: [
                        FloatingActionButton(
                          heroTag: "zoom_in",
                          mini: true,
                          backgroundColor: Colors.white,
                          onPressed: () {
                            _mapController.move(
                              _mapController.camera.center,
                              _mapController.camera.zoom + 1,
                            );
                          },
                          child: const Icon(Icons.add, color: Color(0xFFFF6B35)),
                        ),
                        SizedBox(height: 2.w),
                        FloatingActionButton(
                          heroTag: "zoom_out",
                          mini: true,
                          backgroundColor: Colors.white,
                          onPressed: () {
                            _mapController.move(
                              _mapController.camera.center,
                              _mapController.camera.zoom - 1,
                            );
                          },
                          child: const Icon(Icons.remove, color: Color(0xFFFF6B35)),
                        ),
                        SizedBox(height: 2.w),
                        FloatingActionButton(
                          heroTag: "my_location",
                          mini: true,
                          backgroundColor: Colors.white,
                          onPressed: () async {
                            try {
                              Position position = await Geolocator.getCurrentPosition(
                                desiredAccuracy: LocationAccuracy.high,
                              );
                              final newPosition = LatLng(position.latitude, position.longitude);
                              _mapController.move(newPosition, 15.0);
                              setState(() {
                                _currentPosition = newPosition;
                              });
                              _updateAddress(position.latitude, position.longitude);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Unable to get current location',
                                      style: TextStyle(fontSize: 10.sp),
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
                          },
                          child: const Icon(Icons.my_location, color: Color(0xFFFF6B35)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Address Display
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(5.w),
                  topRight: Radius.circular(5.w),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_pin,
                        color: const Color(0xFFFF6B35),
                        size: 6.w,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'Selected Location',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(3.w),
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    child: _isLoadingAddress
                        ? Row(
                      children: [
                        SpinKitThreeBounce(
                          color: const Color(0xFFFF6B35),
                          size: 17.sp,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          'Getting address...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    )
                        : Text(
                      _currentAddress,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14.sp,
                        height: 1.4,
                      ),
                    ),
                  ),
                  SizedBox(height: 3.w),
                  Text(
                    'Drag the map to adjust your location pin',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11.sp,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}