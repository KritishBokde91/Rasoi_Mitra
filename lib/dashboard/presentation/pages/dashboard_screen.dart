import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rasoi_mitra2/core/utils/app_color.dart';
import 'package:sizer/sizer.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../domain/entities/booking_item.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/repository/booking_service.dart';
import '../../domain/repository/menu_service.dart';
import '../components/enhanced_booking_dialog.dart';
import 'custom_booking_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final MenuService _menuService = MenuService();
  late Razorpay _razorpay;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _animationController.forward();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _animationController.dispose();
    super.dispose();
  }

  String getCurrentDay() {
    return DateFormat('EEEE').format(DateTime.now());
  }

  bool canBookMeal(String mealType) {
    TimeOfDay now = TimeOfDay.now();
    int currentMinutes = now.hour * 60 + now.minute;

    switch (mealType) {
      case 'Breakfast':
        return currentMinutes <= 10 * 60 + 30;
      case 'Lunch':
        return currentMinutes >= 9 * 60 + 30 && currentMinutes <= 14 * 60 + 30;
      case 'Dinner':
        return currentMinutes >= 13 * 60 + 30;
      default:
        return false;
    }
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
        return AppColor.orange;
    }
  }

  IconData _getMealTypeIcon(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return Icons.wb_sunny_outlined;
      case 'Lunch':
        return Icons.wb_sunny;
      case 'Dinner':
        return Icons.nights_stay_outlined;
      default:
        return Icons.restaurant;
    }
  }

  String _getTimeSlot(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return 'Available till 10:30 AM';
      case 'Lunch':
        return '9:30 AM - 2:30 PM';
      case 'Dinner':
        return 'Available after 1:30 PM';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentDay = getCurrentDay();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 15.h,
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
                      padding: EdgeInsets.symmetric(horizontal: 5.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'RasoiMitra',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24.sp,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 0.5.h),
                                    Text(
                                      'Delicious meals for $currentDay',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 7.w,
                                  backgroundColor: Colors.transparent,
                                  child: Icon(
                                    Icons.person_outline,
                                    color: Colors.white,
                                    size: 20.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(6.w),
                      margin: EdgeInsets.only(bottom: 4.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ),
                        borderRadius: BorderRadius.circular(5.w),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF667eea,
                            ).withValues(alpha: 0.4),
                            spreadRadius: 0,
                            blurRadius: 6.w,
                            offset: Offset(0, 2.h),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Today's Special",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  'Fresh meals prepared with love & care',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.all(3.w),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4.w),
                            ),
                            child: Icon(
                              Icons.restaurant_menu,
                              color: Colors.white,
                              size: 9.w,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 1.w,
                          height: 3.5.h,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                            ),
                            borderRadius: BorderRadius.circular(0.8.w),
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          "Today's Menu",
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    FutureBuilder<Map<String, List<MenuItem>>?>(
                      future: _menuService.getMenuForDay(currentDay),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFF6B35),
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'Loading delicious menu...',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data == null) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5.w),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  spreadRadius: 0,
                                  blurRadius: 5.w,
                                  offset: Offset(0, 1.h),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.restaurant_menu,
                                    size: 16.w,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'No menu available for today',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 1.h),
                                  Text(
                                    'Please check back later',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        Map<String, List<MenuItem>> todayMenu = snapshot.data!;

                        return Column(
                          children: todayMenu.entries.map((entry) {
                            String mealType = entry.key;
                            List<MenuItem> items = entry.value;
                            bool canBook = canBookMeal(mealType);

                            return Container(
                              margin: EdgeInsets.only(bottom: 3.h),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6.w),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getMealTypeColor(
                                      mealType,
                                    ).withValues(alpha: 0.1),
                                    spreadRadius: 0,
                                    blurRadius: 6.w,
                                    offset: Offset(0, 2.h),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(6.w),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          _getMealTypeColor(
                                            mealType,
                                          ).withValues(alpha: 0.15),
                                          _getMealTypeColor(
                                            mealType,
                                          ).withValues(alpha: 0.08),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(6.w),
                                        topRight: Radius.circular(6.w),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(4.w),
                                          decoration: BoxDecoration(
                                            color: _getMealTypeColor(
                                              mealType,
                                            ).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                              4.w,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _getMealTypeColor(
                                                  mealType,
                                                ).withValues(alpha: 0.3),
                                                spreadRadius: 0,
                                                blurRadius: 2.5.w,
                                                offset: Offset(0, 1.h),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            _getMealTypeIcon(mealType),
                                            color: _getMealTypeColor(mealType),
                                            size: 7.w,
                                          ),
                                        ),
                                        SizedBox(width: 5.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                mealType,
                                                style: TextStyle(
                                                  fontSize: 18.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getMealTypeColor(
                                                    mealType,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 0.5.h),
                                              Text(
                                                _getTimeSlot(mealType),
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!canBook)
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 3.w,
                                              vertical: 1.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(15.sp),
                                              border: Border.all(
                                                color: Colors.red.shade200,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.access_time_rounded,
                                                  color: Colors.red.shade600,
                                                  size: 6.w,
                                                ),
                                                SizedBox(width: 1.5.w),
                                                Text(
                                                  'Closed',
                                                  style: TextStyle(
                                                    color: Colors.red.shade600,
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: 4.w,
                                      left: 3.w,
                                      right: 3.w,
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 2.w,
                                        vertical: 1.5.h,
                                      ),
                                      margin: EdgeInsets.only(bottom: 2.h),
                                      width: 88.w,
                                      decoration: BoxDecoration(
                                        color: AppColor.menuContentBoxColor,
                                        borderRadius: BorderRadius.circular(
                                          15.sp,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            clipBehavior: Clip.hardEdge,
                                            width: 28.w,
                                            height: 28.w,
                                            padding: EdgeInsets.all(1.w),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20.sp),
                                              image:
                                                  items[0].imageUrl.isNotEmpty
                                                  ? DecorationImage(
                                                      image: NetworkImage(
                                                        items[0].imageUrl,
                                                      ),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                          Container(
                                            width: 28.w,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 2.w,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  items[0].name,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 16.5.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                SizedBox(height: 0.5.h),
                                                Text(
                                                  '₹${items[0].description}',
                                                  style: TextStyle(
                                                    fontSize: 13.sp,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                SizedBox(height: 0.5.h),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 1.7.w,
                                                    vertical: 0.8.h,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.green.shade50,
                                                        Colors.green.shade100,
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          3.w,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          Colors.green.shade200,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.currency_rupee,
                                                        color: Colors
                                                            .green
                                                            .shade700,
                                                        size: 5.w,
                                                      ),
                                                      Text(
                                                        '${items[0].price}',
                                                        style: TextStyle(
                                                          fontSize: 14.sp,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .green
                                                              .shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(4.w),
                                              gradient: canBook
                                                  ? LinearGradient(
                                                      colors: [
                                                        _getMealTypeColor(
                                                          mealType,
                                                        ),
                                                        _getMealTypeColor(
                                                          mealType,
                                                        ).withValues(
                                                          alpha: 0.8,
                                                        ),
                                                      ],
                                                    )
                                                  : null,
                                              color: canBook
                                                  ? null
                                                  : Colors.grey.shade300,
                                              boxShadow: canBook
                                                  ? [
                                                      BoxShadow(
                                                        color:
                                                            _getMealTypeColor(
                                                              mealType,
                                                            ).withValues(
                                                              alpha: 0.3,
                                                            ),
                                                        spreadRadius: 0,
                                                        blurRadius: 3.5.w,
                                                        offset: Offset(0, 1.h),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: ElevatedButton(
                                              onPressed: canBook
                                                  ? () =>
                                                        _showEnhancedBookingDialog(
                                                          mealType,
                                                          items[0],
                                                        )
                                                  : null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 3.w,
                                                  vertical: 1.5.h,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        4.w,
                                                      ),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    canBook
                                                        ? Icons
                                                              .add_shopping_cart_rounded
                                                        : Icons.lock_clock,
                                                    color: canBook
                                                        ? Colors.white
                                                        : Colors.grey.shade600,
                                                    size: 5.w,
                                                  ),
                                                  SizedBox(width: 1.w),
                                                  Text(
                                                    canBook ? 'Book' : 'Closed',
                                                    style: TextStyle(
                                                      color: canBook
                                                          ? AppColor.white
                                                          : AppColor.grey,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14.sp,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    SizedBox(height: 2.h),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColor.customBookingColor1,
                            AppColor.customBookingColor2,
                            AppColor.customBookingColor3,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6.w),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF8B5CF6,
                            ).withValues(alpha: 0.4),
                            spreadRadius: 0,
                            blurRadius: 6.w,
                            offset: Offset(0, 3.h),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(5.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(4.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4.w),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        spreadRadius: 0,
                                        blurRadius: 2.5.w,
                                        offset: Offset(0, 1.h),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.group_add_rounded,
                                    color: Colors.white,
                                    size: 8.w,
                                  ),
                                ),
                                SizedBox(width: 5.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Custom Booking',
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 0.5.h),
                                      Text(
                                        'Perfect for groups of 15+ people',
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w500,
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
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4.w),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    spreadRadius: 0,
                                    blurRadius: 2.5.w,
                                    offset: Offset(0, 1.h),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CustomBookingScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF8B5CF6),
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(
                                    vertical: 1.8.h,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4.w),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 6.w,
                                    ),
                                    SizedBox(width: 3.w),
                                    Text(
                                      'Start Custom Booking',
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 5.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEnhancedBookingDialog(String mealType, MenuItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EnhancedBookingDialog(
        mealType: mealType,
        item: item,
        onBookingConfirmed: _handleBookingConfirmed,
        razorpay: _razorpay,
      ),
    );
  }

  void _handleBookingConfirmed(BookingItem booking) {
    BookingService.addBooking(booking);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.w),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 5.w,
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Booking Confirmed!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                  Text(
                    'Your order has been placed successfully',
                    style: TextStyle(fontSize: 10.sp),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.w)),
        margin: EdgeInsets.all(4.w),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.w),
              ),
              child: Icon(
                Icons.payment_rounded,
                color: Colors.white,
                size: 5.w,
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Payment Successful!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                  Text(
                    'Your order will be prepared soon',
                    style: TextStyle(fontSize: 10.sp),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.w)),
        margin: EdgeInsets.all(4.w),
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.w),
              ),
              child: Icon(Icons.error_rounded, color: Colors.white, size: 5.w),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Payment Failed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                  Text(
                    response.message ?? 'Something went wrong',
                    style: TextStyle(fontSize: 10.sp),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.w)),
        margin: EdgeInsets.all(4.w),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External Wallet: ${response.walletName}'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.w)),
        margin: EdgeInsets.all(4.w),
      ),
    );
  }
}
