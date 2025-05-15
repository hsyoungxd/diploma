import 'package:flutter/material.dart';
import 'package:tengripay/send_money_page.dart';
import 'package:tengripay/transfer_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'deposit_page.dart';
import 'withdraw_page.dart';

class PayPage extends StatefulWidget {
  const PayPage({Key? key}) : super(key: key);

  @override
  _PayPageState createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  double currentBalance = 0.0;
  List<String> friends = [];
  List<Map<String, dynamic>> friendsWithDetails = [];
  List<String> receivedRequests = [];
  List<Map<String, dynamic>> receivedRequestsWithDetails = [];
  List<String> sentRequests = [];
  List<Map<String, dynamic>> sentRequestsWithDetails = [];

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');
    if (token == null || userId == null) {
      print('❌ Нет токена или userId');
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
          currentBalance = (data['balance'] ?? 0).toDouble();
          friends = List<String>.from(data['friends'] ?? []);
          receivedRequests =
              List<String>.from(data['requests']['received'] ?? []);
          sentRequests = List<String>.from(data['requests']['sent'] ?? []);
        });

        final friendsInfoUrl =
            Uri.parse('http://localhost:4000/api/users/friends-info');
        final friendsInfoResponse = await http.post(
          friendsInfoUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'friendsUsernames': friends,
            'receivedUsernames': receivedRequests,
            'sentUsernames': sentRequests,
          }),
        );
        if (friendsInfoResponse.statusCode == 200) {
          final friendsInfo = jsonDecode(friendsInfoResponse.body);
          print(friendsInfo);
          setState(() {
            friendsWithDetails =
                List<Map<String, dynamic>>.from(friendsInfo['friends'] ?? []);
            receivedRequestsWithDetails = List<Map<String, dynamic>>.from(
                friendsInfo['receivedRequests'] ?? []);
            sentRequestsWithDetails = List<Map<String, dynamic>>.from(
                friendsInfo['sentRequests'] ?? []);
          });
          print(friendsWithDetails);
          print(receivedRequestsWithDetails);
          print(sentRequestsWithDetails);
        } else {
          print(
              '⚠️ Ошибка загрузки информации о друзьях: ${friendsInfoResponse.statusCode}');
        }
      } else {
        print('⚠️ Ошибка загрузки профиля: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Ошибка при получении данных: $e');
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
        title: const Text('Pay'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\$ ${currentBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Current Balance',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const Icon(Icons.account_balance_wallet,
                      size: 60, color: Colors.white70),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            SendMoneyPage()), // Navigate to DepositPage
                  ),
                  child: _actionIcon(Icons.send, 'Send Money', primaryGreen),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            DepositPage()), // Navigate to DepositPage
                  ),
                  child:
                      _actionIcon(Icons.description, 'Deposit', primaryGreen),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            WithdrawPage()), // Navigate to WithdrawPage
                  ),
                  child: _actionIcon(
                      Icons.account_balance_wallet, 'Withdraw', primaryGreen),
                ),
                _actionIcon(Icons.qr_code, 'QR Code', primaryGreen),
              ],
            ),
            const SizedBox(height: 40),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Friends',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            // Make the friends list scrollable horizontally
            SizedBox(
              height: 80,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _showAddFriendDialog, // Call method to show dialog
                      child: _addNewFriendButton('Add New',
                          primaryGreen), // Updated function for the 'Add New' button
                    ),
                  ],
                ),
              ),
            ),
            if (friendsWithDetails.isNotEmpty) ...[
              SingleChildScrollView(
                child: Column(
                  children: friendsWithDetails.map((friend) {
                    return GestureDetector(
                      onTap: () {
                        // Здесь добавим логику для перехода на страницу перевода
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TransferPage(
                                friend: friend), // Переход на страницу перевода
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 10), // Добавим отступы между друзьями
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.grey.withOpacity(0.5)), // Граница
                          color: Colors.white, // Белый фон для каждой карточки
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: primaryGreen,
                              radius: 20,
                              backgroundImage: friend['avatar'].isNotEmpty
                                  ? NetworkImage(friend[
                                      'avatar']) // Если есть аватар, показываем его
                                  : null,
                              child: friend['avatar'].isEmpty
                                  ? const Icon(Icons.person,
                                      color: Colors
                                          .white) // Если нет аватара, показываем иконку
                                  : null,
                            ),
                            const SizedBox(
                                width: 10), // Отступ между аватаркой и именем
                            Text(
                              friend['displayname'] ?? 'No Name',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Spacer(), // Чтобы кнопка 'Delete' была справа
                            ElevatedButton(
                              onPressed: () {
                                // Показать диалоговое окно с подтверждением
                                _deleteFriend(friend['username']);
                              },
                              child: const Text('Delete',
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Friend Requests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (receivedRequestsWithDetails.isNotEmpty) ...[
              Column(
                children: receivedRequestsWithDetails.map((friend) {
                  return ListTile(
                    title: Text(friend['username'] ??
                        'No Name'), // Для заявок показываем username
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _acceptFriendRequest(friend['username']);
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          child: const Text('Accept'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            _declineFriendRequest(friend['username']);
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          child: const Text('Decline'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sent Friend Requests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            // Display sent friend requests
            if (sentRequestsWithDetails.isNotEmpty) ...[
              Column(
                children: sentRequestsWithDetails.map((friend) {
                  return ListTile(
                    title: Text(friend['username'] ??
                        'No Name'), // Для отправленных запросов показываем username
                    trailing: ElevatedButton(
                      onPressed: () {
                        _cancelFriendRequest(friend['username']);
                      },
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red), // Красная кнопка
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

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController usernameController = TextEditingController();
        return AlertDialog(
          title: const Text('Add Friend'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Enter Username',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        String username = usernameController.text;
                        if (username.isNotEmpty) {
                          // Send the request to backend to add friend
                          await _sendFriendRequest(username);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a username'),
                            ),
                          );
                        }
                      },
                      child: const Text('Add by Username'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelFriendRequest(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');

    if (token == null || userId == null) {
      print('❌ Нет токена или userId');
      return;
    }

    try {
      final url = Uri.parse(
          'http://localhost:4000/api/users/cancel-friend-request'); // Путь на бэке для отмены заявки
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'friendUsername':
              username, // Отправляем username того, кому была отправлена заявка
        }),
      );

      if (response.statusCode == 200) {
        // Если запрос успешен, обновляем список
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Friend request canceled successfully!')),
        );
        loadUserData(); // Перезагружаем данные, чтобы обновить состояние
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Error occurred')),
        );
      }
    } catch (e) {
      print('⚠️ Ошибка при отмене заявки: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error canceling friend request')),
      );
    }
  }

// Function to send a friend request to the server
  Future<void> _sendFriendRequest(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');

    if (token == null || userId == null) {
      print('❌ No token or userId');
      return;
    }

    try {
      final url = Uri.parse(
          'http://localhost:4000/api/users/add-friend'); // Update with correct endpoint
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'friendUsername': username,
        }),
      );

      if (response.statusCode == 200) {
        // Assuming response indicates the friend request was successful
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent successfully!')),
        );
        Navigator.of(context).pop(); // Закрыть диалог
        loadUserData();
      } else if (response.statusCode == 404) {
        // Handle 404: user not found
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'User not found')),
        );
      } else if (response.statusCode == 400) {
        // Handle 400: already sent or other bad request errors
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Error occurred')),
        );
      } else {
        // Handle failure, e.g. user not found
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Error occurred')),
        );
      }
    } catch (e) {
      print('⚠️ Error sending friend request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error sending friend request')),
      );
    }
  }

  Future<void> _acceptFriendRequest(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');

    if (token == null || userId == null) {
      print('❌ Нет токена или userId');
      return;
    }

    try {
      final url = Uri.parse(
          'http://localhost:4000/api/users/accept-friend-request'); // Путь на бэке для принятия заявки
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'friendUsername':
              username, // Отправляем username того, кто отправил заявку
        }),
      );

      if (response.statusCode == 200) {
        // Если запрос успешен, обновляем список
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Friend request accepted successfully!')),
        );
        loadUserData(); // Перезагружаем данные, чтобы обновить состояние
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Error occurred')),
        );
      }
    } catch (e) {
      print('⚠️ Ошибка при принятии заявки: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error accepting friend request')),
      );
    }
  }

  Future<void> _declineFriendRequest(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');

    if (token == null || userId == null) {
      print('❌ Нет токена или userId');
      return;
    }

    try {
      final url = Uri.parse(
          'http://localhost:4000/api/users/decline-friend-request'); // Путь на бэке для отклонения заявки
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'friendUsername':
              username, // Отправляем username того, кто отправил заявку
        }),
      );

      if (response.statusCode == 200) {
        // Если запрос успешен, обновляем список
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Friend request declined successfully!')),
        );
        loadUserData(); // Перезагружаем данные, чтобы обновить состояние
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Error occurred')),
        );
      }
    } catch (e) {
      print('⚠️ Ошибка при отклонении заявки: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error declining friend request')),
      );
    }
  }

  Future<void> _deleteFriend(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');

    if (token == null || userId == null) {
      print('❌ No token or userId');
      return;
    }

    // Подтверждение удаления
    bool confirm = await _showDeleteConfirmationDialog(username);
    if (!confirm) {
      return; // Если пользователь отменил, не выполняем удаление
    }

    try {
      final url = Uri.parse('http://localhost:4000/api/users/delete-friend');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'friendUsername': username,
        }),
      );

      if (response.statusCode == 200) {
        // Успех, друг был удален
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend deleted successfully!')),
        );
        setState(() {
          // Обновим список друзей после удаления
          friendsWithDetails
              .removeWhere((friend) => friend['username'] == username);
        });
      } else {
        // Ошибка на сервере
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Error occurred')),
        );
      }
    } catch (e) {
      print('⚠️ Error deleting friend: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error deleting friend')),
      );
    }
  }

// Показывает диалог для подтверждения удаления друга
  Future<bool> _showDeleteConfirmationDialog(String username) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content:
                  Text('Are you sure you want to delete friend "$username"?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false); // Отменить
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true); // Подтвердить
                  },
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Widget _actionIcon(IconData icon, String label, Color color) => Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 30,
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );

  Widget _addNewFriendButton(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 25,
            child: Icon(Icons.add, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _friendAvatar(Map<String, dynamic> friend) {
    String avatar = friend['avatar'] ?? '';
    String displayName = friend['displayname'] ?? 'No Name';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green,
            radius: 25,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child:
                avatar.isEmpty ? Icon(Icons.person, color: Colors.white) : null,
          ),
          const SizedBox(height: 4),
          Text(displayName, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
