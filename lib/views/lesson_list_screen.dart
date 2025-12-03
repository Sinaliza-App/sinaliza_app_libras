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
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Meu Perfil',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
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
                  '${snapshot.error}',
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
              final bool isCompleted = completedIds.contains(lesson['id']);

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
        http.get(Uri.parse('$baseUrl/progress'), headers: headers),
      ]);
      final lessonsResponse = responses[0];
      final progressResponse = responses[1];
      if (lessonsResponse.statusCode != 200) {
        _handleApiError(lessonsResponse.statusCode);
        throw Exception(
          'Erro ao carregar lições: ${lessonsResponse.statusCode}',
        );
      }
      final List<dynamic> lessonsData = json.decode(lessonsResponse.body);
      final List<Map<String, dynamic>> lessons = lessonsData
          .cast<Map<String, dynamic>>();
      if (progressResponse.statusCode != 200) {
        _handleApiError(progressResponse.statusCode);
        throw Exception(
          'Erro ao carregar progresso: ${progressResponse.statusCode}',
        );
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
