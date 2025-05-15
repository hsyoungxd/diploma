import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FeedPage extends StatefulWidget {
  const FeedPage({Key? key}) : super(key: key);

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<dynamic> transactions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadFeed();
  }

  Future<void> loadFeed() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      print('❌ No token');
      return;
    }

    try {
      final url = Uri.parse('http://localhost:4000/api/feed');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          transactions = data;
          isLoading = false;
        });
      } else {
        print('⚠️ Failed to load feed: ${response.body}');
      }
    } catch (e) {
      print('⚠️ Error loading feed: $e');
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
        title: const Text('Tengri Feed'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.credit_card, color: primaryGreen),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : transactions.isEmpty
              ? const Center(child: Text('No public transactions yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(20.0),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    final title =
                        '${t['fromUsername']} paid ${t['toUsername']}';
                    final note = t['note'] ?? '';
                    final amount = '\$${t['amount'].toString()}';
                    final date = DateTime.tryParse(t['date'] ?? '')?.toLocal();
                    final formattedDate = date != null
                        ? '${date.day}/${date.month}/${date.year}'
                        : 'Date?';
                    return _buildFeedItem(
                        title, note, amount, formattedDate, primaryGreen);
                  },
                ),
    );
  }

  Widget _buildFeedItem(String title, String subtitle, String amount,
      String date, Color amountColor,
      {bool isOwn = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
      leading: const CircleAvatar(
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.thumb_up_off_alt_outlined,
                  size: 18, color: Colors.grey),
              SizedBox(width: 4),
              Text('Like', style: TextStyle(color: Colors.grey)),
              SizedBox(width: 20),
            ],
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(date, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(amount,
              style:
                  TextStyle(color: amountColor, fontWeight: FontWeight.bold)),
          if (isOwn)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Manage',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
