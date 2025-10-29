import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/lesson_list_screen.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';

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
    // Inicia a verificação assim que a tela é construída
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Adiciona um pequeno delay para a splash screen (opcional, mas bom para UI)
    await Future.delayed(const Duration(seconds: 1));

    // Tenta ler o token do storage
    final String? token = await _storage.read(key: 'jwt_token');

    if (!mounted) return;

    // TODO: Adicionar lógica para validar o token com a API
    // (Por enquanto, só checamos se ele existe)

    if (token != null) {
      // Se o token existe, vá para a tela principal (Login automático)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LessonListScreen()),
      );
    } else {
      // Se não existe token, vá para a tela de Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Uma tela de loading simples
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}