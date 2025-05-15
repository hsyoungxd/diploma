import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:tengripay/deposit_page.dart';
import 'package:tengripay/home_screen.dart';
import 'package:tengripay/send_money_page.dart';
import 'package:tengripay/withdraw_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

const primaryGreen = Color(0xFF007438);

class _HomePageState extends State<HomePage> {
  String displayName = '';
  String username = '';
  double balance = 0.0;
  List<Map<String, dynamic>> transactions = [];
  String avatarUrl = '';

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');
    if (token == null || userId == null) return;

    try {
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
          displayName = data['displayname'] ?? '';
          username = data['username'] ?? '';
          balance = (data['balance'] ?? 0).toDouble();
          transactions =
              List<Map<String, dynamic>>.from(data['transactions'] ?? []);
          avatarUrl = data['avatar'] ?? '';
        });
      }
    } catch (e) {
      print('Ошибка загрузки: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Hello, $displayName', style: TextStyle(color: Colors.white)),
            CircleAvatar(
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tengri Card',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(username,
                      style: TextStyle(color: Colors.white, fontSize: 20)),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('VALID THRU',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Text('unlimited',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                      Icon(Icons.credit_card, color: Colors.white, size: 40),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(displayName, style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Insight',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                      Text('Current Balance',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  Text('\$ ${balance.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.white, fontSize: 20)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAction(Icons.send, 'Send Money', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SendMoneyPage()),
                  );
                }),
                _buildAction(Icons.description, 'Deposit', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DepositPage()),
                  );
                }),
                _buildAction(Icons.account_balance_wallet, 'Withdraw', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const WithdrawPage()),
                  );
                }),
                _buildAction(Icons.qr_code, 'QR Code', () {
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(builder: (context) => const QRPage()),
                  // );
                }),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Transactions',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const HomeScreen(initialIndex: 1),
                  )),
                  child: const Text('View All',
                      style: TextStyle(color: primaryGreen)),
                ),
              ],
            ),
            ...transactions
                .where((tx) => tx['type'] == 'transfer')
                .toList()
                .sorted((a, b) => DateTime.parse(b['date'])
                    .compareTo(DateTime.parse(a['date'])))
                .take(3)
                .map((tx) => FutureBuilder<String>(
                      future: fetchRecipientUsername(
                        tx['to'] == username ? tx['from'] : tx['to'],
                      ),
                      builder: (context, snapshot) {
                        final isIncome = tx['to'] == username;
                        final name = snapshot.data ?? 'Loading...';
                        return ListTile(
                          leading: Icon(Icons.monetization_on,
                              color: isIncome ? primaryGreen : Colors.red),
                          title: Text(name),
                          subtitle: Text(formatDate(tx['date'])),
                          trailing: Text(
                            '\$${tx['amount']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isIncome ? primaryGreen : Colors.red,
                            ),
                          ),
                        );
                      },
                    ))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(IconData icon, String label, VoidCallback onTap) =>
      Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              radius: 25,
              child: Icon(icon, color: primaryGreen, size: 25),
            ),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );

  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')} - ${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Future<String> fetchRecipientUsername(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return 'Unknown';

    final response = await http.get(
      Uri.parse('http://localhost:4000/api/users/username/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['username'] ?? 'Unknown';
    } else {
      print('Failed to load user ${response.statusCode}');
      return 'Unknown';
    }
  }
}
