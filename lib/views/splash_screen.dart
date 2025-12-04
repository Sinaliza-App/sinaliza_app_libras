import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';
import 'package:sinaliza_app_libras/views/module_list_screen.dart'; // Importe a nova home
import 'package:http/http.dart' as http;
import 'dart:convert';
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
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 1));
    final String? token = await _storage.read(key: 'jwt_token');

    if (token == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    const String apiUrl = 'http://26.72.151.39:3000/users/me';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        Provider.of<UserProvider>(context, listen: false).setUser(userData);
        
        // REDIRECIONAMENTO ATUALIZADO PARA A TELA DE MÓDULOS
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ModuleListScreen()),
        );
      } else {
        await _storage.delete(key: 'jwt_token');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      await _storage.delete(key: 'jwt_token');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBG = Color(0xFF02040A);
    const Color neonGreen = Color(0xFF00FF9D);

    return const Scaffold(
      backgroundColor: darkBG,
      body: Center(
        child: CircularProgressIndicator(color: neonGreen),
      ),
    );
  }
}