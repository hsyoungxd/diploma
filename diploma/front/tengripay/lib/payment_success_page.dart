import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tengripay/home_page.dart';
import 'package:tengripay/home_screen.dart';

const primaryGreen = Color(0xFF007438);

class PaymentSuccessPage extends StatelessWidget {
  final String recipientUsername;
  final double amount;
  final DateTime timestamp;
  final bool isRequest;

  const PaymentSuccessPage({
    Key? key,
    required this.recipientUsername,
    required this.amount,
    required this.timestamp,
    this.isRequest = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final charge = 0.0;
    final total = amount + charge;
    final formattedTime = DateFormat('MM/dd/yy, hh:mma').format(timestamp);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Payment'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryGreen, width: 4),
              ),
              padding: const EdgeInsets.all(16),
              child: const Icon(Icons.check, color: primaryGreen, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              isRequest ? 'Request Sent' : 'Payment Success',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '@$recipientUsername',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            _buildRow('Amount', '\$${amount.toStringAsFixed(2)}'),
            _buildRow('Charge', '\$${charge.toStringAsFixed(2)}'),
            _buildRow('Total', '\$${total.toStringAsFixed(2)}'),
            _buildRow('Timestamp', formattedTime),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomeScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Back To Home',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: Colors.black54)),
          Text(value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primaryGreen,
              )),
        ],
      ),
    );
  }
}
