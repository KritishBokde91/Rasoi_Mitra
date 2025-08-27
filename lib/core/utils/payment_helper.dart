import 'package:flutter/material.dart';

class PaymentHelper {
  static const String razorpayKeyId = 'rzp_test_1DP5mmOlF5G5ag';

  static Map<String, dynamic> getPaymentOptions({
    required double amount,
    required String itemName,
    required String mealType,
    String? customerEmail,
    String? customerPhone,
  }) {
    return {
      'key': razorpayKeyId,
      'amount': (amount * 100).toInt(), // Amount in paise
      'name': 'RasoiMitra',
      'description': '$itemName - $mealType',
      'prefill': {
        'contact': customerPhone ?? '9999999999',
        'email': customerEmail ?? 'customer@rasoimitra.com'
      },
      'theme': {
        'color': '#FF6B35'
      },
      'modal': {
        'ondismiss': () {
          print('Payment dismissed');
        }
      },
      'external': {
        'wallets': ['paytm']
      }
    };
  }

  static void showPaymentErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Payment Failed'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void showPaymentSuccessDialog(BuildContext context, String paymentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green),
            SizedBox(width: 12),
            Text('Payment Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your payment has been processed successfully.'),
            const SizedBox(height: 8),
            Text(
              'Payment ID: $paymentId',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}