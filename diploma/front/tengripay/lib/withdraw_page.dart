import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Importing services for TextInputFormatter
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({Key? key}) : super(key: key);

  @override
  _WithdrawPageState createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  TextEditingController amountController = TextEditingController();
  TextEditingController cardNumberController =
      TextEditingController(); // Controller for card number
  TextEditingController cardHolderController =
      TextEditingController(); // Controller for cardholder name
  bool isProcessing = false; // To prevent multiple button presses
  List<Map<String, String>> savedCards = []; // To store saved cards

  @override
  void initState() {
    super.initState();
    loadSavedCard();
  }

  // Load saved card details from the backend
  Future<void> loadSavedCard() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');

    if (token == null || userId == null) {
      print('❌ No token or userId');
      return;
    }

    try {
      final url = Uri.parse(
          'http://localhost:4000/api/users/$userId'); // Endpoint to fetch user data
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Получаем список карт как List<Map<String, dynamic>>
        final cards = data['cards'] as List<dynamic>;

        // Преобразуем в List<Map<String, String>>
        if (cards.isNotEmpty) {
          setState(() {
            savedCards = cards.map((card) {
              // Преобразуем каждую карту в Map<String, String>
              return {
                'cardNumber': card['cardNumber']?.toString() ?? '',
                'cardHolder': card['cardHolder']?.toString() ??
                    '', // Include card holder name
              };
            }).toList();
          });
        }
      } else {
        print('⚠️ Error loading card data: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error during card data retrieval: $e');
    }
  }

  Future<void> handleWithdraw() async {
    final amount = double.tryParse(amountController.text) ?? 0.0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Amount must be greater than 0')),
      );
      return;
    }

    if (cardNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide a card number')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');

    if (token == null || userId == null) {
      print('❌ No token or userId');
      return;
    }

    setState(() {
      isProcessing = true; // Disable the button to prevent multiple presses
    });

    try {
      final url = Uri.parse('http://localhost:4000/api/transactions/withdraw');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'amount': amount,
          'cardNumber': cardNumberController.text,
          'cardHolder': cardHolderController.text, // Send cardHolder name
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Withdrawal successful')),
        );
        Navigator.pop(context); // Go back to the previous page
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('⚠️ Error during withdrawal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during withdrawal')),
      );
    } finally {
      setState(() {
        isProcessing = false; // Re-enable the button after processing
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF007438);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Withdraw Money'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Withdraw Money',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen),
            ),

            const SizedBox(height: 20),
            TextField(
              controller: cardNumberController, // Card number field
              keyboardType: TextInputType.number,
              maxLength: 16, // Max length for card number
              decoration: const InputDecoration(
                labelText: 'Card Number',
                labelStyle: TextStyle(color: primaryGreen),
                prefixIcon: Icon(Icons.credit_card, color: primaryGreen),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryGreen),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryGreen),
                ),
                fillColor: Colors.white30,
                filled: true,
                counterText: "",
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly, // Allow only numbers
              ],
            ),
            const SizedBox(height: 20),
            // Input for cardholder name
            TextField(
              controller: cardHolderController, // Cardholder name field
              decoration: const InputDecoration(
                labelText: 'Cardholder Name',
                labelStyle: TextStyle(color: primaryGreen),
                prefixIcon: Icon(Icons.person, color: primaryGreen),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryGreen),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryGreen),
                ),
                fillColor: Colors.white30,
                filled: true,
              ),
            ),

            const SizedBox(height: 20),

            // Display saved cards

            // Input for amount
            TextField(
              controller: amountController, // Amount field
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                labelStyle: TextStyle(color: primaryGreen),
                prefixIcon: Icon(Icons.attach_money, color: primaryGreen),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryGreen),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryGreen),
                ),
                fillColor: Colors.white30,
                filled: true,
              ),
            ),

            const SizedBox(height: 20),

            // Withdraw Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: isProcessing
                    ? null
                    : () {
                        handleWithdraw();
                      },
                child: isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Withdraw',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),

            const SizedBox(height: 20),
            if (savedCards.isNotEmpty) ...[
              const Text(
                'Saved Cards',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen),
              ),
              const SizedBox(height: 10),
              Column(
                children: savedCards.map((card) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        cardNumberController.text = card['cardNumber']!;
                        cardHolderController.text =
                            card['cardHolder']!; // Set cardholder name
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: primaryGreen),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.credit_card, color: primaryGreen),
                          const SizedBox(width: 10),
                          Text(
                            card['cardNumber']!,
                            style: const TextStyle(color: primaryGreen),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
