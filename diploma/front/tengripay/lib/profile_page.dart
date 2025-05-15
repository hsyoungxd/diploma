import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF007438);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        title: const Text('Profile Settings',
            style: TextStyle(color: primaryGreen)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryGreen),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: primaryGreen),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          _settingItem(Icons.edit, 'Edit profile'),
          _settingItem(Icons.business, 'Create business profile'),
          _settingItem(Icons.payment, 'Payment methods'),
          _settingItem(Icons.privacy_tip, 'Privacy'),
          _settingItem(Icons.phone, 'Change phone number'),
          _settingItem(Icons.notifications, 'Notifications'),
          _settingItem(Icons.add_circle, 'Add new account'),
          _settingItem(Icons.logout, 'Log out'),
          _settingItem(Icons.support_agent, 'Support service'),
        ],
      ),
    );
  }

  Widget _settingItem(IconData icon, String label) => ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {},
      );
}
