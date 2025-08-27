import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import '../../domain/entities/booking_item.dart';

class BookingDetailsScreen extends StatelessWidget {
  final BookingItem booking;
  final String docId;
  final String imageUrl;

  const BookingDetailsScreen({
    super.key,
    required this.booking,
    required this.docId,
    required this.imageUrl,
  });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Order #$docId',
          style: const TextStyle(
            color: Color(0xFF2D3748),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(5.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Status
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: _getStatusColor(booking.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.w),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Status: ${booking.status}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(booking.status),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: _getStatusColor(booking.status),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Text(
                      booking.status.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 3.h),
            // Order Item
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4.w),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.08),
                    spreadRadius: 0,
                    blurRadius: 5.w,
                    offset: Offset(0, 1.h),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20.w,
                    height: 20.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3.w),
                      image: DecorationImage(
                        image: NetworkImage(
                          imageUrl.isNotEmpty
                              ? imageUrl
                              : 'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=300&h=300&fit=crop&crop=center',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.item,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D3748),
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          'Meal Type: ${booking.mealType}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          'Quantity: ${booking.quantity}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          'Total: ₹${booking.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 3.h),
            // Booking Details
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4.w),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.08),
                    spreadRadius: 0,
                    blurRadius: 5.w,
                    offset: Offset(0, 1.h),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking Details',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3748),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  _buildDetailRow('Order ID', docId),
                  _buildDetailRow('Booking Time', DateFormat('MMM dd, yyyy hh:mm a').format(booking.bookingTime)),
                  _buildDetailRow('Delivery Date', DateFormat('MMM dd, yyyy hh:mm a').format(booking.deliveryDate)),
                  _buildDetailRow('Payment Method', booking.paymentMethod),
                  _buildDetailRow('Address', booking.address),
                  if (booking.latitude != null && booking.longitude != null)
                    _buildDetailRow('Coordinates', '${booking.latitude!.toStringAsFixed(4)}, ${booking.longitude!.toStringAsFixed(4)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.sp,
                color: const Color(0xFF2D3748),
              ),
            ),
          ),
        ],
      ),
    );
  }
}