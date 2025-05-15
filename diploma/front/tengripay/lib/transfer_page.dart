import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:tengripay/payment_success_page.dart';

const primaryGreen = Color(0xFF007438);

class TransferPage extends StatefulWidget {
  final Map<String, dynamic> friend;

  const TransferPage({Key? key, required this.friend}) : super(key: key);

  @override
  _TransferPageState createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  double currentBalance = 0.0;
  bool _isPublic = false;
  bool _isRequest = false;

  @override
  void initState() {
    super.initState();
    loadBalance();
  }

  Future<void> loadBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');
    if (token == null || userId == null) return;

    final url = Uri.parse('http://localhost:4000/api/users/$userId');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        currentBalance = (data['balance'] ?? 0).toDouble();
      });
    }
  }

  Future<void> sendMoney() async {
    final amountText = _amountController.text.trim();
    final note = _noteController.text.trim();

    if (amountText.isEmpty || double.tryParse(amountText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    final amount = double.parse(amountText);

    if (amount > currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authorization failed')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://localhost:4000/api/transactions/send'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'recipient': widget.friend['username'],
          'amount': amount,
          'note': note,
          'isPublic': _isPublic,
        }),
      );

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentSuccessPage(
              recipientUsername: widget.friend['username'],
              amount: double.parse(_amountController.text),
              timestamp: DateTime.now(),
              isRequest: true,
            ),
          ),
        );
      } else {
        final body = jsonDecode(response.body);
        final message = body['message'] ?? 'Something went wrong';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> requestMoney() async {
    final amountText = _amountController.text.trim();
    final note = _noteController.text.trim();

    if (amountText.isEmpty || double.tryParse(amountText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    final amount = double.parse(amountText);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authorized')),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('http://localhost:4000/api/transactions/request'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'recipient': widget.friend['username'],
        'amount': amount,
        'note': note,
        'isPublic': _isPublic,
      }),
    );

    if (response.statusCode == 200) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentSuccessPage(
            recipientUsername: widget.friend['username'],
            amount: double.parse(_amountController.text),
            timestamp: DateTime.now(),
            isRequest: true,
          ),
        ),
      );
    } else {
      final msg = jsonDecode(response.body)['message'] ?? 'Request failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendName = widget.friend['displayname'] ?? 'No Name';
    final friendAvatar = widget.friend['avatar'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Payment'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // ...твой контент
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 40,
                  backgroundImage:
                      friendAvatar != null && friendAvatar.isNotEmpty
                          ? NetworkImage(friendAvatar)
                          : null,
                  child: friendAvatar == null || friendAvatar.isEmpty
                      ? const Icon(Icons.person, size: 40, color: primaryGreen)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  friendName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 60),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.attach_money, color: primaryGreen),
                    hintText: '0.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                  style: const TextStyle(fontSize: 20, color: primaryGreen),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14),
                    children: [
                      const TextSpan(
                        text: 'Current Balance ',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      TextSpan(
                        text: '\$${currentBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Notes',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText: 'Enter a note (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: primaryGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isPublic = !_isPublic;
                    });
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _isPublic ? primaryGreen : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: primaryGreen, width: 2),
                        ),
                        child: _isPublic
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Share on Tengri Feed',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          SwitchListTile(
            title: const Text(
              'Request instead of send',
              style: TextStyle(fontSize: 16),
            ),
            activeColor: primaryGreen,
            value: _isRequest,
            onChanged: (value) {
              setState(() {
                _isRequest = value;
              });
            },
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () async {
                _isRequest ? await requestMoney() : await sendMoney();
              },
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.width / 2,
                decoration: const BoxDecoration(
                  color: primaryGreen,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(1000),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isRequest
                          ? Icons.request_page_rounded
                          : Icons.send_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRequest ? 'Request Money' : 'Send Money',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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
    );
  }
}
