import 'package:flutter/material.dart';
import 'package:tengripay/home_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TengriPay',
      // theme: ThemeData(
      // primaryColor: const Color(0xFF007438),
      // colorScheme:
      //     ColorScheme.fromSeed(seedColor: const Color(0xFF007438))),
      home: const WelcomeScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Image.asset('assets/home.jpg'),
            ),
            const Text(
              'Welcome to TengriPay',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(60),
                backgroundColor: const Color(0xFF007438),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text('Create new account',
                  style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('I already have an account',
                  style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 70),
          ],
        ),
      ),
    );
  }
}
