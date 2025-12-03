import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/lesson_detail_screen.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';
import 'package:sinaliza_app_libras/views/profile_page.dart';

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
  // Correção: Definindo a variável _dataFuture que faltava
  late Future<CombinedLessonData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchLessonsAndProgress();
  }

  void _refreshData() {
    setState(() {
      _dataFuture = _fetchLessonsAndProgress();
    });
  }

  Future<CombinedLessonData> _fetchLessonsAndProgress() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      _logout();
      throw Exception('Token não encontrado.');
    }

    const String baseUrl = 'http://26.72.151.39:3000'; // Use seu IP
    final headers = {'Authorization': 'Bearer $token'};

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/lessons'), headers: headers),
        http.get(Uri.parse('$baseUrl/progress'), headers: headers)
      ]);

      final lessonsResponse = responses[0];
      final progressResponse = responses[1];

      if (lessonsResponse.statusCode != 200) throw Exception('Erro lessons');
      if (progressResponse.statusCode != 200) throw Exception('Erro progress');

      final List<dynamic> lessonsData = json.decode(lessonsResponse.body);
      final List<Map<String, dynamic>> lessons = lessonsData.cast<Map<String, dynamic>>();

      final List<dynamic> progressData = json.decode(progressResponse.body);
      final Set<int> completedIds = progressData.map((p) => p['lesson_id'] as int).toSet();

      return CombinedLessonData(lessons: lessons, completedLessonIds: completedIds);
    } catch (e) {
      throw Exception('Erro de conexão: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lições de Libras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProfilePage())),
          ),
        ],
      ),
      body: FutureBuilder<CombinedLessonData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Nenhuma lição encontrada.'));
          }

          final lessons = snapshot.data!.lessons;
          // Correção: Usando completedLessonIds que vem do snapshot
          final completedIds = snapshot.data!.completedLessonIds;

          return ListView.builder(
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              final isCompleted = completedIds.contains(lesson['id']);

              return ListTile(
                title: Text(lesson['title']),
                trailing: isCompleted ? const Icon(Icons.check_circle, color: Colors.green) : null,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => LessonDetailScreen(lesson: lesson)),
                  );
                  if (mounted) _refreshData();
                },
              );
            },
          );
        },
      ),
    );
  }
}