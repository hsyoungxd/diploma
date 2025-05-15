import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Importing services for TextInputFormatter
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class DepositPage extends StatefulWidget {
  const DepositPage({Key? key}) : super(key: key);

  @override
  _DepositPageState createState() => _DepositPageState();
}

class _DepositPageState extends State<DepositPage> {
  TextEditingController cardNumberController = TextEditingController();
  TextEditingController expirationMonthController = TextEditingController();
  TextEditingController expirationYearController = TextEditingController();
  TextEditingController cvvController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  TextEditingController cardHolderController = TextEditingController();

  bool isCardSaved = false;
  bool isProcessing = false; // To prevent multiple button presses
  List<Map<String, String>> savedCards = [];
  String? selectedCard;

  @override
  void initState() {
    super.initState();
    loadSavedCard();
  }

  // Load saved card details from the backend
  // Создание переменной типа List<Map<String, dynamic>>

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
      // final url = Uri.parse('http://localhost:4002/$userId');
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
                'cardHolder': card['cardHolder']?.toString() ?? '',
                'expirationMonth': card['expirationMonth']?.toString() ?? '',
                'expirationYear': card['expirationYear']?.toString() ?? '',
                'cvv': card['cvv']?.toString() ?? '',
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

  Future<void> deleteCard(String cardNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');

    if (token == null || userId == null) {
      print('❌ No token or userId');
      return;
    }

    try {
      final url = Uri.parse('http://localhost:4000/api/users/remove-card');
      // final url = Uri.parse('http://localhost:4002/remove-card');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'cardNumber': cardNumber,
        }),
      );

      if (response.statusCode == 200) {
        // Remove the card from the local list of cards
        setState(() {
          savedCards.removeWhere((card) => card['cardNumber'] == cardNumber);
        });
      } else {
        print('⚠️ Error deleting card: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error during card deletion: $e');
    }
  }

  Future<void> handleDeposit() async {
    final amount = double.tryParse(amountController.text) ?? 0.0;
    final expirationMonth = int.tryParse(expirationMonthController.text) ?? 0;
    final expirationYear = int.tryParse(expirationYearController.text) ?? 0;

    if (cardNumberController.text.isEmpty ||
        expirationMonthController.text.isEmpty ||
        expirationYearController.text.isEmpty ||
        cvvController.text.isEmpty ||
        cardHolderController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide a full card info')),
      );
      return;
    }

    if (cardNumberController.text.length != 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Card number must be 16 digits')),
      );
      return;
    }

    if (expirationMonth <= 0 || expirationMonth > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid month')),
      );
      return;
    }

    if (expirationYear == 25 && expirationMonth <= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid expiration date')),
      );
      return;
    } else if (expirationYear < 25) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid year')),
      );
      return;
    }

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid amount')),
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
      final url = Uri.parse('http://localhost:4000/api/transactions/deposit');
      // final url = Uri.parse('http://localhost:4003/deposit');
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
          'expirationMonth': expirationMonthController.text,
          'expirationYear': expirationYearController.text,
          'cvv': cvvController.text,
          'cardHolder': cardHolderController.text,
          "isSaved": isCardSaved
        }),
      );

      if (response.statusCode == 200) {
        // Update balance
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deposit successful')),
        );
        Navigator.pop(context); // Go back to the previous page
      } else {
        print('⚠️ Deposit error: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('⚠️ Error during deposit: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during deposit')),
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
        title: const Text('Deposit Money'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deposit Money',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: cardNumberController,
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
            const SizedBox(height: 10),

            Row(
              children: [
                // Expiration Date
                Expanded(
                  child: TextField(
                    controller: expirationMonthController,
                    keyboardType: TextInputType.number,
                    maxLength: 2, // MM/YY format (max 5 chars)
                    decoration: const InputDecoration(
                      labelText: 'MM',
                      labelStyle: TextStyle(color: primaryGreen),
                      prefixIcon: Icon(Icons.date_range, color: primaryGreen),
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
                      FilteringTextInputFormatter
                          .digitsOnly, // Allow only numbers
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: expirationYearController,
                    keyboardType: TextInputType.number,
                    maxLength: 2, // MM/YY format (max 5 chars)
                    decoration: const InputDecoration(
                      labelText: 'YY',
                      labelStyle: TextStyle(color: primaryGreen),
                      prefixIcon: Icon(Icons.date_range, color: primaryGreen),
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
                      FilteringTextInputFormatter
                          .digitsOnly, // Allow only numbers
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // CVV (Max 3 digits)
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: cvvController,
                    keyboardType: TextInputType.number,
                    maxLength: 3, // Limit to 3 digits for CVV
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      labelStyle: TextStyle(color: primaryGreen),
                      prefixIcon: Icon(Icons.security, color: primaryGreen),
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
                      FilteringTextInputFormatter
                          .digitsOnly, // Allow only numbers
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: cardHolderController, // Cardholder Name
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
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp('[A-Za-z]')), // Only upper case letters
                TextInputFormatter.withFunction((oldValue, newValue) {
                  String transformedText = newValue.text
                      .toUpperCase(); // Преобразуем в заглавные буквы
                  return newValue.copyWith(
                      text: transformedText); // Возвращаем новый текст
                }),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController, // Контроллер для суммы
              keyboardType: TextInputType.numberWithOptions(
                  decimal: true), // Для чисел с десятичными знаками
              inputFormatters: [
                FilteringTextInputFormatter
                    .digitsOnly, // Разрешаем только цифры
              ],
              decoration: const InputDecoration(
                labelText: 'Amount', // Лейбл для суммы
                labelStyle: TextStyle(color: primaryGreen),
                prefixIcon:
                    Icon(Icons.attach_money, color: primaryGreen), // Иконка
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
            // Save Card Checkbox styled as a button
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isCardSaved = !isCardSaved;
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCardSaved ? primaryGreen : Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCardSaved
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCardSaved ? 'Card Saved' : 'Save Card',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // Deposit Button
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: isProcessing
                        ? null
                        : () {
                            handleDeposit();
                          },
                    child: isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Deposit',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Display saved cards
            savedCards.isNotEmpty
                ? Column(
                    children: savedCards.map((card) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            cardNumberController.text = card['cardNumber']!;
                            expirationMonthController.text =
                                card['expirationMonth']!;
                            expirationYearController.text =
                                card['expirationYear']!;
                            cvvController.text = card['cvv']!;
                            cardHolderController.text = card['cardHolder']!;
                            selectedCard = card['cardNumber'];
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
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: primaryGreen),
                                onPressed: () {
                                  deleteCard(card['cardNumber']!);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : const SizedBox.shrink(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
