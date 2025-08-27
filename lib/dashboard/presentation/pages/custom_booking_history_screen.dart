import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import '../../domain/entities/booking_item.dart';
import 'booking_detail_screen.dart';

class CustomBookingsHistoryScreen extends StatefulWidget {
  const CustomBookingsHistoryScreen({super.key});

  @override
  State<CustomBookingsHistoryScreen> createState() => _CustomBookingsHistoryScreenState();
}

class _CustomBookingsHistoryScreenState extends State<CustomBookingsHistoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final List<GlobalKey> _refreshKeys = [
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFFF6B35);
      case 'Confirmed':
        return const Color(0xFF2ECC71);
      case 'Cancelled':
        return const Color(0xFFE74C3C);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.pending;
      case 'Confirmed':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCustomBookings(String? status) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return [];
      }

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('custom_bookings')
          .where('userUID', isEqualTo: user.uid);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      debugPrint('Error fetching custom bookings: $e');
      rethrow;
    }
  }

  BookingItem _mapToBookingItem(Map<String, dynamic> data) {
    try {
      return BookingItem(
        id: data['id'] ?? 'Unknown',
        mealType: data['mealType'] ?? 'Unknown',
        item: data['item'] ?? 'Unknown Item',
        bookingTime: (data['bookingTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        deliveryDate: (data['deliveryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        status: data['status'] ?? 'Unknown',
        price: 0.0, // Price not used
        quantity: data['quantity'] ?? 1,
        address: data['address'] ?? 'No address provided',
        paymentMethod: data['paymentMethod'] ?? 'Unknown',
        isCustom: data['isCustom'] ?? true,
      );
    } catch (e) {
      debugPrint('Error mapping custom booking item: $e');
      return BookingItem(
        id: 'Error',
        mealType: 'Unknown',
        item: 'Error Item',
        bookingTime: DateTime.now(),
        deliveryDate: DateTime.now(),
        status: 'Unknown',
        price: 0.0,
        quantity: 1,
        address: 'Error',
        paymentMethod: 'Unknown',
        isCustom: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 20.h,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF6B35),
                      Color(0xFFFF8E53),
                      Color(0xFFFFAD71),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.history,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Custom Bookings',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Track your custom meal orders',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFFAD71)],
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _fetchCustomBookings(null),
                        builder: (context, snapshot) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.list_alt, size: 18),
                              const SizedBox(width: 8),
                              Text('All (${snapshot.data?.length ?? 0})'),
                            ],
                          );
                        },
                      ),
                    ),
                    Tab(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _fetchCustomBookings('Pending'),
                        builder: (context, snapshot) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.pending, size: 18),
                              const SizedBox(width: 8),
                              Text('Pending (${snapshot.data?.length ?? 0})'),
                            ],
                          );
                        },
                      ),
                    ),
                    Tab(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _fetchCustomBookings('Confirmed'),
                        builder: (context, snapshot) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 18),
                              const SizedBox(width: 8),
                              Text('Done (${snapshot.data?.length ?? 0})'),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCustomBookingsList(null, 'No custom bookings yet', 'Start placing custom orders!', 0),
                _buildCustomBookingsList('Pending', 'No pending custom bookings', 'All your custom orders are confirmed!', 1),
                _buildCustomBookingsList('Confirmed', 'No confirmed custom bookings', 'Complete some custom orders first!', 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomBookingsList(String? status, String emptyTitle, String emptySubtitle, int tabIndex) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: _refreshKeys[tabIndex],
      future: _fetchCustomBookings(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading custom bookings: ${snapshot.error.toString().split(':').last.trim()}',
                  style: TextStyle(color: Colors.red, fontSize: 16.sp),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _refreshKeys[tabIndex] = GlobalKey();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }
        final bookings = snapshot.data?.map((data) => _mapToBookingItem(data)).toList() ?? [];
        if (bookings.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  emptyTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  emptySubtitle,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return CustomRefreshIndicator(
          onRefresh: () async {
            setState(() {
              _refreshKeys[tabIndex] = GlobalKey();
            });
            await _fetchCustomBookings(status);
          },
          builder: (context, child, controller) {
            return AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final value = controller.value.clamp(0.0, 1.0);
                return Stack(
                  children: [
                    Transform.translate(
                      offset: Offset(0, value * 100),
                      child: child,
                    ),
                    Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Opacity(
                          opacity: value,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: CircularProgressIndicator(
                              value: value,
                              color: const Color(0xFFFF6B35),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              BookingItem booking = bookings[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookingDetailsScreen(
                        booking: booking,
                        docId: snapshot.data![index]['id'],
                        imageUrl: snapshot.data![index]['imageUrl'] ?? '',
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.08),
                        spreadRadius: 0,
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _getStatusColor(booking.status).withOpacity(0.1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(booking.status).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getStatusIcon(booking.status),
                                  color: _getStatusColor(booking.status),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Order #${snapshot.data![index]['id']}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF718096),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('MMM dd, yyyy • hh:mm a').format(booking.bookingTime),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(booking.status),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  booking.status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            snapshot.data![index]['imageUrl'] ??
                                                'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=300&h=300&fit=crop&crop=center',
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            booking.item,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2D3748),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF667eea).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  booking.mealType,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF667eea),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'CUSTOM',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF8B5CF6),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.group,
                                                size: 16,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${booking.quantity} people',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (booking.status == 'Confirmed') ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.schedule, color: Colors.blue.shade600, size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Estimated Delivery',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                            Text(
                                              DateFormat('MMM dd, yyyy hh:mm a').format(booking.deliveryDate),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.blue.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}