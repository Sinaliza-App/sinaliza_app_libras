import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';
import 'package:sinaliza_app_libras/views/module_list_screen.dart';

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
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // 1. Espera um pouquinho (2 segundos) para mostrar a logo bonita
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 2. Tenta ler o token salvo
    String? token = await _storage.read(key: 'jwt_token');

    // 3. Decisão:
    if (token != null && token.isNotEmpty) {
      // TEM TOKEN -> Vai direto para a Home (Módulos)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ModuleListScreen()),
      );
    } else {
      // NÃO TEM TOKEN -> Vai para Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sua tela bonita com logo e loading neon
    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Se tiver uma logo, coloque aqui. Se não, use o ícone/texto:
            const Icon(Icons.waving_hand_outlined, size: 80, color: Color(0xFF00FF9D)),
            const SizedBox(height: 20),
            const Text(
              "SINALIZA",
              style: TextStyle(
                color: Color(0xFF00FF9D),
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Color(0xFF00FF9D)),
          ],
        ),
      ),
    );
  }
}