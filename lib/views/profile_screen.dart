import 'package:flutter/material.dart';
import 'package:sinaliza_app_libras/helpers/database_helper.dart';
import 'dart:developer' as developer;
import 'package:sinaliza_app_libras/views/lesson_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final dbHelper = DatabaseHelper();

  void _saveUser() async {
    final name = _nameController.text;
    final email = _emailController.text;

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos.')),
      );
      return;
    }

    // Bloco try-catch para capturar o erro
    try {
      final user = {'name': name, 'email': email};

      developer.log(
        'Tentando inserir no banco de dados...',
        name: 'ProfileScreen',
      ); // Mensagem de debug
      final id = await dbHelper.insertUser(user);
      developer.log(
        'Inserção retornou o ID: $id',
        name: 'ProfileScreen',
      ); // Mensagem de debug

      if (!mounted) return;

      if (id > 0) {
        // Navegação em caso de SUCESSO
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário salvo com sucesso!'),
            duration: Duration(seconds: 1), // Mensagem mais rápida
          ),
        );

        // 2. Adicione a navegação aqui
        // Espera um pouco para o usuário ver a mensagem e depois navega
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return; // garante que o widget ainda está montado
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LessonListScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este e-mail já está em uso.')),
        );
      }
    } catch (e) {
      // Se um erro ocorrer no bloco 'try', ele será capturado aqui
      developer.log(
        '--- ERRO AO SALVAR USUÁRIO ---',
        name: 'ProfileScreen',
        level: 1000,
      );
      developer.log(
        e.toString(),
        name: 'ProfileScreen',
        level: 1000,
      ); // Isso vai registrar o erro exato no console
      developer.log(
        '------------------------------',
        name: 'ProfileScreen',
        level: 1000,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _saveUser, child: const Text('Salvar')),
          ],
        ),
      ),
    );
  }
}
