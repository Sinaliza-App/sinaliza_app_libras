import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/lesson_detail_screen.dart'; // Para a navegação
import 'package:sinaliza_app_libras/views/login_screen.dart'; // Para fazer logout
import 'package:sinaliza_app_libras/views/profile_page.dart'; // Para ir ao perfil

// Classe auxiliar para combinar os dados das duas chamadas de API
class CombinedLessonData {
  final List<Map<String, dynamic>> lessons;
  final Set<int> completedLessonIds;

  CombinedLessonData({required this.lessons, required this.completedLessonIds});
}

class LessonListScreen extends StatefulWidget {
  const LessonListScreen({super.key});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  final _storage = const FlutterSecureStorage();
  // O Future agora vai esperar pelos dados combinados
  late Future<CombinedLessonData> _dataFuture;

  @override
  void initState() {
    super.initState();
    // Inicia a busca pelos dados combinados
    _dataFuture = _fetchLessonsAndProgress();
  }

  // Função para buscar ambas as rotas da API em paralelo
  Future<CombinedLessonData> _fetchLessonsAndProgress() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      _logout();
      throw Exception('Token não encontrado. Fazendo logout.');
    }

    // ATENÇÃO: Use '10.0.2.2' (Android) ou 'localhost' (Desktop)
    const String baseUrl = 'http://10.0.2.2:3000'; 
    final headers = {'Authorization': 'Bearer $token'};

    try {
      // Faz as duas chamadas à API em paralelo
      final lessonsResponseFuture = http.get(Uri.parse('$baseUrl/lessons'), headers: headers);
      final progressResponseFuture = http.get(Uri.parse('$baseUrl/progress'), headers: headers);

      // Espera as duas terminarem
      final responses = await Future.wait([lessonsResponseFuture, progressResponseFuture]);

      final lessonsResponse = responses[0];
      final progressResponse = responses[1];

      // Verifica a resposta das Lições
      if (lessonsResponse.statusCode != 200) {
        _handleApiError(lessonsResponse.statusCode);
        throw Exception('Erro ao carregar lições: ${lessonsResponse.statusCode}');
      }
      final List<dynamic> lessonsData = json.decode(lessonsResponse.body);
      final List<Map<String, dynamic>> lessons = lessonsData.cast<Map<String, dynamic>>();

      // Verifica a resposta do Progresso
      if (progressResponse.statusCode != 200) {
        _handleApiError(progressResponse.statusCode);
        throw Exception('Erro ao carregar progresso: ${progressResponse.statusCode}');
      }
      final List<dynamic> progressData = json.decode(progressResponse.body);
      
      // Cria um Set (conjunto) com os IDs das lições completadas
      final Set<int> completedLessonIds = progressData
          .map((progress) => progress['lesson_id'] as int)
          .toSet();

      // Retorna os dados combinados
      return CombinedLessonData(
        lessons: lessons,
        completedLessonIds: completedLessonIds,
      );

    } catch (e) {
      // Erro de rede (timeout, API desligada)
      throw Exception('Erro de conexão: $e');
    }
  }

  // Função de utilidade para tratar erros de API e deslogar
  void _handleApiError(int statusCode) {
    if (statusCode == 401 || statusCode == 400) {
      _logout();
    }
  }

  // Função de utilidade para deslogar o usuário
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
        ],
      ),
      body: FutureBuilder<CombinedLessonData>(
        future: _dataFuture, 
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
                  '${snapshot.error}', // Mostra o erro exato
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          // 3. Se os dados não vieram (pouco provável, mas é bom checar)
          if (!snapshot.hasData) {
            return const Center(child: Text('Nenhuma lição encontrada.'));
          }

          // 4. Pega os dados do snapshot
          final lessons = snapshot.data!.lessons;
          final completedIds = snapshot.data!.completedLessonIds;

          if (lessons.isEmpty) {
            return const Center(child: Text('Nenhuma lição cadastrada.'));
          }

          // 5. Se tudo deu certo, construa a lista.
          return ListView.builder(
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              final bool isCompleted = completedIds.contains(lesson['id']);

              return ListTile(
                leading: const Icon(Icons.sign_language),
                title: Text(lesson['title']),
                subtitle: Text(lesson['description']),
                
                // ADICIONA O ÍCONE DE "CHECK"
                trailing: isCompleted
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null, // Não mostra nada se não estiver completa

                onTap: () {
                  // Navega para a tela de detalhes
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