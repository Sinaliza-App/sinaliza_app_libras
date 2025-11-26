import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sinaliza_app_libras/views/login_screen.dart';
import 'package:sinaliza_app_libras/views/lesson_list_screen.dart';
import 'package:provider/provider.dart';
import 'package:sinaliza_app_libras/providers/user_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2)); // pequena animação

    final token = await _storage.read(key: 'jwt_token');

    if (token == null) {
      _goToLogin();
      return;
    }

    try {
      // Verifica se o token é válido
      const String apiUrl = 'http://26.72.151.39:3000/users/me';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        if (!mounted) return;
        Provider.of<UserProvider>(context, listen: false).setUser(userData);

        _goToHome();
      } else {
        _logout();
      }
    } catch (e) {
      _logout();
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LessonListScreen()),
    );
  }

  void _logout() async {
    await _storage.delete(key: 'jwt_token');
    _goToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
