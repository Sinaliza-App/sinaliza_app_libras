import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Para fazer as requisições
import 'dart:convert'; // Para usar json.encode e json.decode
import 'package:sinaliza_app_libras/views/lesson_list_screen.dart'; // Para navegar após o sucesso

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false; // Variável para mostrar um indicador de loading

  void _saveUser() async {
    final name = _nameController.text;
    final email = _emailController.text;
    final password = _passwordController.text;

    // 1. Validação local (frontend)
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos.')),
      );
      return;
    }

    // 2. Ativa o indicador de loading
    setState(() {
      _isLoading = true;
    });

    // ATENÇÃO: Se estiver no Emulador Android, use '10.0.2.2' para o localhost do PC.
    const String apiUrl = 'http://10.0.2.2:3000/users/register';
    // Se estiver no app Desktop (Windows), pode usar 'localhost':
    // const String apiUrl = 'http://localhost:3000/users/register';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10)); // Adiciona um timeout

      if (!mounted) return;

      // 3. Decodifica a resposta do servidor
      final responseData = json.decode(response.body);

      // 4. Trata a resposta baseado no StatusCode
      if (response.statusCode == 201) {
        // --- SUCESSO ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Sucesso!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LessonListScreen()),
        );
      } else if (response.statusCode == 409) {
        // --- CONFLITO (Email já existe) ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'E-mail já cadastrado.')),
        );
      } else {
        // --- OUTROS ERROS (400, 500, etc.) ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Erro desconhecido.')),
        );
      }

    } catch (e) {
      // 5. Trata erros de rede (timeout, API desligada, sem internet)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: $e. Verifique se a API está online.')),
      );
    } finally {
      // 6. Desativa o indicador de loading, independente do resultado
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Perfil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
              enabled: !_isLoading, // Desabilita campos durante o loading
            ),
            const SizedBox(height: 10),
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
            // 7. Mostra o botão ou o "loading"
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveUser,
                    child: const Text('Salvar Usuário'),
                  ),
          ],
        ),
      ),
    );
  }
}