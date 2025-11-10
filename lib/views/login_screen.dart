import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sinaliza_app_libras/views/lesson_list_screen.dart'; // Para onde iremos após o login
import 'package:sinaliza_app_libras/views/profile_screen.dart'; // Para o usuário poder se cadastrar
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 1. IMPORTADO

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  // 2. CRIADA A INSTÂNCIA DO STORAGE
  final _storage = const FlutterSecureStorage();

  Future<void> _loginUser() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha e-mail e senha.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // ATENÇÃO: Use '10.0.2.2' se estiver no Emulador Android
    const String apiUrl = 'http://10.0.2.2:3000/users/login';
    // Se estiver no app Desktop (Windows), pode usar 'localhost':
    // const String apiUrl = 'http://localhost:3000/users/login';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // --- SUCESSO! MODIFICAÇÃO AQUI ---
        
        // 3. Pegue o token da resposta
        final String token = responseData['token'];
        
        // 4. Salve o token com segurança no dispositivo
        await _storage.write(key: 'jwt_token', value: token);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Login bem-sucedido!')),
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LessonListScreen()),
        );
      } else {
        // --- ERROS (401, 400, 500) ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'E-mail ou senha inválidos.')),
        );
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: $e. Verifique se a API está online.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _goToRegisterScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'E-mail'),
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Senha'),
              obscureText: true,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _loginUser,
                    child: const Text('Entrar'),
                  ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _isLoading ? null : _goToRegisterScreen,
              child: const Text('Não tem uma conta? Cadastre-se'),
            ),
          ],
        ),
      ),
    );
  }
}