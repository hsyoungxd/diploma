import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Importing services for TextInputFormatter
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data'; // For working with base64 image data
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({Key? key}) : super(key: key);

  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  bool isIncomeSelected = true; // Default selection for Income
  bool isExpenseSelected = false; // Default selection for Expense
  double balance = 0.0; // To store balance value
  List<Map<String, dynamic>> transactions =
      []; // List to store transaction data
  double totalIncome = 0.0; // To store total income
  double totalExpense = 0.0; // To store total expense
  String userId = ''; // Variable to store userId

  @override
  void initState() {
    super.initState();
    _getUserId(); // Fetch userId from SharedPreferences
    loadBalanceAndTransactions(); // Load balance and transactions on initialization
  }

  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')} - ${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Function to get userId from SharedPreferences
  Future<void> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final storedUserId = prefs.getString('userId');
    if (token == null || storedUserId == null) {
      print('❌ No token or userId');
      return;
    }

    setState(() {
      userId = storedUserId; // Set userId from SharedPreferences
    });
  }

  // Function to fetch balance and transactions from the server
  Future<void> loadBalanceAndTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || userId.isEmpty) {
      print('❌ No token or userId');
      return;
    }

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
          balance = (data['balance'] is int)
              ? (data['balance'] as int).toDouble()
              : data['balance'].toDouble();
          transactions = List<Map<String, dynamic>>.from(data['transactions']);

          // Calculate total income and total expense based on transactions
          totalIncome = transactions
              .where((transaction) =>
                  transaction['to'] == userId) // Check if 'to' matches userId
              .fold(0.0, (sum, transaction) {
            return sum +
                (transaction['amount'] is int
                    ? (transaction['amount'] as int).toDouble()
                    : transaction['amount']);
          });

          totalExpense = transactions
              .where((transaction) =>
                  transaction['from'] ==
                  userId) // Check if 'to' does not match userId
              .fold(0.0, (sum, transaction) {
            return sum +
                (transaction['amount'] is int
                    ? (transaction['amount'] as int).toDouble()
                    : transaction['amount']);
          });
        });
      } else {
        print('⚠️ Error loading data: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error during data retrieval: $e');
    }
  }

  // Filter transactions based on selected category
  List<Map<String, dynamic>> getFilteredTransactions() {
    if (userId.isEmpty) {
      return []; // Return an empty list if userId is not available
    }
    return transactions.where((transaction) {
      final isTransfer = transaction['type'] == 'transfer';
      final isDeposit = transaction['type'] == 'deposit';
      final isWithdrawal = transaction['type'] == 'withdrawal';

      if (isIncomeSelected &&
          ((isDeposit && transaction['to'] == userId) ||
              (isTransfer && transaction['to'] == userId))) {
        return true;
      }

      if (isExpenseSelected &&
          ((isWithdrawal && transaction['from'] == userId) ||
              (isTransfer && transaction['from'] == userId))) {
        return true;
      }

      return false;
    }).toList()
      ..sort((a, b) =>
          DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
  }

  // Fetch the recipient's username for a transfer transaction
  Future<String> fetchRecipientUsername(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('❌ No token');
        return 'Unknown User';
      }

      final response = await http.get(
        Uri.parse('http://localhost:4000/api/users/username/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['username'] ?? 'Unknown User';
      } else {
        print('⚠️ Failed to load user. Status: ${response.statusCode}');
        return 'Unknown User';
      }
    } catch (e) {
      print('❌ Error fetching user: $e');
      return 'Unknown User';
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF007438);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Statistics'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                transactions.isEmpty
                    ? Container(
                        height: 260,
                        width: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade300,
                        ),
                      )
                    : Transform.rotate(
                        angle: -1.5708, // ⬅️ -90 градусов (по часовой стрелке)
                        child: SizedBox(
                          height: 260, // ⬆️ Сделал круг больше
                          width: 260,
                          child: PieChart(
                            PieChartData(
                              startDegreeOffset: 0, // Начало сверху
                              sectionsSpace: 0,
                              centerSpaceRadius: 80, // Центр для текста
                              sections: [
                                PieChartSectionData(
                                  value: totalExpense,
                                  color: Colors.red,
                                  showTitle: false,
                                  radius: 20, // Сделал толще
                                ),
                                PieChartSectionData(
                                  value: totalIncome,
                                  color: Color(0xFF007438),
                                  showTitle: false,
                                  radius: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '\$${balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Balance', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),

            // SizedBox(
            //   height: 200,
            //   width: 200,
            //   child: PieChart(
            //     PieChartData(
            //       sections: [
            //         PieChartSectionData(
            //           value: totalExpense,
            //           color: Colors.red,
            //           title: '',
            //           radius: 20,
            //         ),
            //         PieChartSectionData(
            //           value: totalIncome,
            //           color: Color(0xFF007438),
            //           title: '',
            //           radius: 20,
            //         ),
            //       ],
            //       centerSpaceRadius: 60,
            //       sectionsSpace: 0,
            //     ),
            //   ),
            // ),

            // CircularPercentIndicator(
            //   radius: 100.0,
            //   lineWidth: 20.0,
            //   percent: totalIncome == 0
            //       ? 0
            //       : (balance / totalIncome).clamp(0.0, 1.0),
            //   center: Column(
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       Text(
            //         '\$${balance.toStringAsFixed(2)}',
            //         style: const TextStyle(
            //           fontSize: 24,
            //           fontWeight: FontWeight.bold,
            //         ),
            //       ),
            //       const Text('Balance', style: TextStyle(color: Colors.grey)),
            //     ],
            //   ),
            //   progressColor: const Color(0xFF007438), // зелёный
            //   backgroundColor: Colors.grey.shade200,
            //   circularStrokeCap: CircularStrokeCap.round,
            // ),

            const SizedBox(height: 20),
            Row(
              children: [
                // Dynamically display total income
                _statCard(Icons.attach_money, 'Income',
                    '\$${totalIncome.toStringAsFixed(2)}', Colors.green),
                // Dynamically display total expense
                _statCard(Icons.calculate, 'Expense',
                    '\$${totalExpense.toStringAsFixed(2)}', Colors.red),
              ],
            ),
            const SizedBox(height: 20),
            // Category selection with checkboxes
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _categoryButton('Income', isIncomeSelected, () {
                  setState(() {
                    isIncomeSelected = !isIncomeSelected;
                  });
                }),
                const SizedBox(width: 10),
                _categoryButton('Expense', isExpenseSelected, () {
                  setState(() {
                    isExpenseSelected = !isExpenseSelected;
                  });
                }),
              ],
            ),
            const SizedBox(height: 20),
            // Transactions List
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transactions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            // Display filtered transactions
            ...getFilteredTransactions().map((transaction) {
              return _transactionTile(transaction);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _categoryButton(
      String label, bool isSelected, VoidCallback onPressed) {
    const primaryGreen = Color(0xFF007438);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? (label == 'Expense' ? Colors.red : primaryGreen)
            : Colors.grey, // Change color based on selection
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        minimumSize: Size(150, 50), // Make buttons wider
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _statCard(
      IconData icon, String label, String amount, Color iconColor) {
    return Expanded(
      // Чтобы карточки делили ширину поровну
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 36),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(
                  amount,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget _statCard(
  //     IconData icon, String label, String amount, Color iconColor) {
  //   return Container(
  //     padding: const EdgeInsets.all(15),
  //     decoration: BoxDecoration(
  //       color: iconColor.withOpacity(0.1),
  //       borderRadius: BorderRadius.circular(15),
  //     ),
  //     child: Column(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         Icon(icon, color: iconColor, size: 30),
  //         const SizedBox(height: 8),
  //         Text(amount,
  //             style:
  //                 const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
  //         const SizedBox(height: 4),
  //         Text(label, style: const TextStyle(fontSize: 14)),
  //       ],
  //     ),
  //   );
  // }

  Widget _transactionTile(Map<String, dynamic> transaction) {
    const primaryGreen = Color(0xFF007438);
    final isIncome = transaction['to'] == userId;
    final iconColor = isIncome ? primaryGreen : Colors.red;

    return ListTile(
      leading: Icon(
        transaction['type'] == 'transfer'
            ? Icons.monetization_on
            : Icons.payment,
        color: iconColor,
      ),
      title: transaction['type'] == 'transfer'
          ? FutureBuilder<String>(
              future: fetchRecipientUsername(
                transaction['to'] == userId
                    ? transaction['from']
                    : transaction['to'],
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Text(snapshot.data ?? 'Unknown');
                } else {
                  return const Text('Loading...');
                }
              },
            )
          : Text(transaction['type'] == 'deposit' ? 'Deposit' : 'Withdrawal'),
      subtitle: Text(formatDate(transaction['date'] ?? '')),
      trailing: Text(
        '\$${transaction['amount']}',
        style: TextStyle(
          fontSize: 16,
          color: isIncome ? primaryGreen : Colors.red,
        ),
      ),
    );
  }
}
