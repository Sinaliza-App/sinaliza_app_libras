import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/lesson_detail_screen.dart'; // Para a navegação
import 'package:sinaliza_app_libras/views/login_screen.dart'; // Para fazer logout em caso de erro
import 'package:sinaliza_app_libras/views/profile_page.dart';

class LessonListScreen extends StatefulWidget {
  const LessonListScreen({super.key});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  final _storage = const FlutterSecureStorage();
  late Future<List<Map<String, dynamic>>> _lessonsFuture;

  @override
  void initState() {
    super.initState();
    // Inicia a busca pelas lições assim que a tela é criada
    _lessonsFuture = _fetchLessons();
  }

  // --- NOVA FUNÇÃO PARA BUSCAR LIÇÕES DA API ---
  Future<List<Map<String, dynamic>>> _fetchLessons() async {
    // 1. Ler o token salvo
    final token = await _storage.read(key: 'jwt_token');

    // Se não tiver token, algo está errado (tecnicamente, a SplashScreen já deveria ter pego isso)
    if (token == null) {
      _logout();
      throw Exception('Token não encontrado. Fazendo logout.');
    }

    // ATENÇÃO: Use '10.0.2.2' se estiver no Emulador Android
    const String apiUrl = 'http://10.0.2.2:3000/lessons';
    // Se estiver no app Desktop (Windows), pode usar 'localhost':
    // const String apiUrl = 'http://localhost:3000/lessons';

    try {
      final response = await http
          .get(
            Uri.parse(apiUrl),
            headers: {
              // 2. Enviar o "crachá" (JWT) no cabeçalho
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // --- SUCESSO ---
        // Converte a resposta JSON (que é uma lista) em uma List<Map<String, dynamic>>
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401 || response.statusCode == 400) {
        // --- FALHA NA AUTENTICAÇÃO ---
        // Token inválido ou expirado. Faça o logout.
        _logout();
        throw Exception('Sessão expirada. Por favor, faça o login novamente.');
      } else {
        // --- OUTROS ERROS DE SERVIDOR ---
        throw Exception('Erro ao carregar lições: ${response.statusCode}');
      }
    } catch (e) {
      // Erro de rede (timeout, API desligada)
      // (Opcional: em um app real, aqui você tentaria ler do cache SQLite)
      throw Exception('Erro de conexão: $e');
    }
  }

  // Função de utilidade para deslogar o usuário e levá-lo ao Login
  void _logout() async {
    await _storage.delete(key: 'jwt_token');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false, // Remove todas as telas anteriores
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lições de Libras'),
        // TODO: Adicionar um botão de "Perfil" ou "Sair" aqui
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            tooltip: 'Meu Perfil',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Sair',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _lessonsFuture, // O Future que o builder vai "ouvir"
        builder: (context, snapshot) {
          // 1. Enquanto os dados estão carregando, mostre um spinner.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. Se ocorreu um erro na busca.
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Erro ao carregar as lições.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          // 3. Se os dados foram carregados com sucesso, mas a lista está vazia.
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma lição encontrada.'));
          }

          // 4. Se tudo deu certo, construa a lista.
          final lessons = snapshot.data!;
          return ListView.builder(
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              return ListTile(
                leading: const Icon(Icons.sign_language),
                title: Text(lesson['title']),
                subtitle: Text(lesson['description']),
                onTap: () {
                  // Navega para a tela de detalhes (código que você já tinha)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LessonDetailScreen(lesson: lesson),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
