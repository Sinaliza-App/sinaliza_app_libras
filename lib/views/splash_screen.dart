import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/lesson_list_screen.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';
import 'package:http/http.dart' as http; // 1. Importe o http
import 'dart:convert'; // 2. Importe o dart:convert
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
    // Inicia a verificação assim que a tela é construída
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Adiciona um pequeno delay (opcional, mas bom para UI)
    await Future.delayed(const Duration(seconds: 1));

    // 1. Tenta ler o token do storage
    final String? token = await _storage.read(key: 'jwt_token');

    if (token == null) {
      // Se não existe token, vá para a tela de Login
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    // 2. Se o token EXISTE, vamos VALIDÁ-LO com a API
    // ATENÇÃO: Use '10.0.2.2' se estiver no Emulador Android
    const String apiUrl = 'http://10.0.2.2:3000/users/me';
    // Se estiver no app Desktop (Windows), pode usar 'localhost':
    // const String apiUrl = 'http://localhost:3000/users/me';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          // 3. Enviamos o "crachá" (token) no cabeçalho
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

        if (response.statusCode == 200) {
        // --- SUCESSO! MODIFICAÇÃO AQUI ---
        
        // 2. Decodifica os dados do usuário
          final userData = json.decode(response.body);

        // 3. Salva o usuário no Provider (Gerenciador de Estado Global)
          Provider.of<UserProvider>(context, listen: false).setUser(userData);
        
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LessonListScreen()),
        );
      } else {
        // --- FALHA (401, 400) ---
        // O token é inválido ou expirou.
        // Apagamos o token "podre" do celular.
        await _storage.delete(key: 'jwt_token');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      // 4. Erro de rede (sem internet, API desligada)
      // Não podemos validar, então mandamos para o Login por segurança.
      if (!mounted) return;
      await _storage.delete(key: 'jwt_token'); // Limpa o token por via das dúvidas
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