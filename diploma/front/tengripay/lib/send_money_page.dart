import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:tengripay/transfer_page.dart';

const primaryGreen = Color(0xFF007438);

class SendMoneyPage extends StatefulWidget {
  const SendMoneyPage({Key? key}) : super(key: key);

  @override
  State<SendMoneyPage> createState() => _SendMoneyPageState();
}

class _SendMoneyPageState extends State<SendMoneyPage> {
  List<Map<String, dynamic>> friends = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadFriends();
  }

  // Оставляем только этот метод
  Future<void> checkAndNavigate(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final currentUsername = prefs.getString('username');
    print(currentUsername);

    if (token == null || searchQuery.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите username')),
      );
      return;
    }

    try {
      final url = Uri.parse('http://localhost:4000/api/users/username-info');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'username': searchQuery.trim()}),
      );

      if (response.statusCode == 200) {
        final friend = jsonDecode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransferPage(friend: friend),
          ),
        );
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь не найден')),
        );
      } else {
        final error = jsonDecode(response.body);
        final message = error['message'] ?? 'Неизвестная ошибка';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      print('Ошибка запроса: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка подключения к серверу')),
      );
    }
  }

  Future<void> loadFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');

    if (token == null || userId == null) return;
    try {
      final profileUrl = Uri.parse('http://localhost:4000/api/users/$userId');
      final profileRes = await http.get(profileUrl, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      if (profileRes.statusCode != 200) return;

      final profileData = jsonDecode(profileRes.body);
      final friendUsernames = List<String>.from(profileData['friends'] ?? []);
      print(friendUsernames);
      final infoUrl = Uri.parse('http://localhost:4000/api/users/friends-info');
      final infoRes = await http.post(infoUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'friendsUsernames': friendUsernames,
            'receivedUsernames': [],
            'sentUsernames': [],
          }));
      print(infoRes.body);
      if (infoRes.statusCode == 200) {
        final info = jsonDecode(infoRes.body);
        setState(() {
          friends = List<Map<String, dynamic>>.from(info['friends'] ?? []);
        });
      }
    } catch (e) {
      print('Ошибка загрузки друзей: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredFriends = friends.where((f) {
      final username = f['username']?.toLowerCase() ?? '';
      final displayname = f['displayname']?.toLowerCase() ?? '';
      return username.contains(searchQuery.toLowerCase()) ||
          displayname.contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Send Money'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryGreen,
        onPressed: () {
          // Будущая реализация: сканировать QR-код
        },
        child: const Icon(Icons.qr_code),
      ),
      body: Column(
        children: [
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search by username',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (searchQuery.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ElevatedButton(
                onPressed: () {
                  checkAndNavigate(context);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: Colors.white,
                  backgroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Continue', style: TextStyle(fontSize: 16)),
              ),
            ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('My Friends',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filteredFriends.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final friend = filteredFriends[index];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundImage: friend['avatar'] != null &&
                            friend['avatar'].toString().isNotEmpty
                        ? NetworkImage(friend['avatar'])
                        : null,
                    child: friend['avatar'] == null ||
                            friend['avatar'].toString().isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(
                    friend['displayname'],
                    style: const TextStyle(
                      fontSize: 18, // Увеличили
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransferPage(friend: friend),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
