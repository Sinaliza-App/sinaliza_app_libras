import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/lesson_detail_screen.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';
import 'package:sinaliza_app_libras/views/profile_page.dart';

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

// ===================================================================
// TUDO A PARTIR DAQUI ESTÁ DENTRO DA CLASSE _LessonListScreenState
// ===================================================================
class _LessonListScreenState extends State<LessonListScreen> {
  
  // --- 1. PROPRIEDADES DA CLASSE ---
  final _storage = const FlutterSecureStorage();
  late Future<CombinedLessonData> _dataFuture;

  // --- 2. MÉTODOS DE CICLO DE VIDA (ex: initState) ---
  @override
  void initState() {
    super.initState();
    // Inicia a busca pelos dados combinados
    _dataFuture = _fetchLessonsAndProgress();
  }

  // --- 3. MÉTODO DE CONSTRUÇÃO DA UI (o build) ---
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
          // ... (Lógica do FutureBuilder: waiting, error, etc.)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.lessons.isEmpty) {
            return const Center(child: Text('Nenhuma lição encontrada.'));
          }

          final lessons = snapshot.data!.lessons;
          final completedIds = snapshot.data!.completedLessonIds;

          return ListView.builder(
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              final bool isCompleted = completedIds.contains(lesson['id']);

              return ListTile(
                leading: const Icon(Icons.sign_language),
                title: Text(lesson['title']),
                subtitle: Text(lesson['description']),
                trailing: isCompleted
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null, 
                onTap: () async {
                  // Espera o usuário voltar da tela de detalhes
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LessonDetailScreen(lesson: lesson),
                    ),
                  );
                  // Quando o usuário voltar, atualiza a lista!
                  if (!mounted) return;
                  _refreshData(); // <-- Agora funciona
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshData, // <-- Agora funciona
        tooltip: 'Atualizar Lições',
        child: const Icon(Icons.refresh),
      ),
    );
  } // <-- FIM DO MÉTODO build()

  
  // --- 4. OUTRAS FUNÇÕES DA CLASSE ---
  // (Elas ficam DENTRO da classe, mas FORA do 'build')
  
  void _refreshData() {
    setState(() {
      _dataFuture = _fetchLessonsAndProgress();
    });
  }

  Future<CombinedLessonData> _fetchLessonsAndProgress() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      _logout();
      throw Exception('Token não encontrado. Fazendo logout.');
    }
    const String baseUrl = 'http://10.0.2.2:3000'; 
    final headers = {'Authorization': 'Bearer $token'};
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/lessons'), headers: headers),
        http.get(Uri.parse('$baseUrl/progress'), headers: headers)
      ]);
      final lessonsResponse = responses[0];
      final progressResponse = responses[1];
      if (lessonsResponse.statusCode != 200) {
        _handleApiError(lessonsResponse.statusCode);
        throw Exception('Erro ao carregar lições: ${lessonsResponse.statusCode}');
      }
      final List<dynamic> lessonsData = json.decode(lessonsResponse.body);
      final List<Map<String, dynamic>> lessons = lessonsData.cast<Map<String, dynamic>>();
      if (progressResponse.statusCode != 200) {
        _handleApiError(progressResponse.statusCode);
        throw Exception('Erro ao carregar progresso: ${progressResponse.statusCode}');
      }
      final List<dynamic> progressData = json.decode(progressResponse.body);
      final Set<int> completedLessonIds = progressData
          .map((progress) => progress['lesson_id'] as int)
          .toSet();
      return CombinedLessonData(
        lessons: lessons,
        completedLessonIds: completedLessonIds,
      );
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  void _handleApiError(int statusCode) {
    if (statusCode == 401 || statusCode == 400) {
      _logout();
    }
  }

  void _logout() async {
    await _storage.delete(key: 'jwt_token');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

} // <-- FIM DA CLASSE _LessonListScreenState