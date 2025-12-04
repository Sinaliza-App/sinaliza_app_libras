import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/lesson_instruction_screen.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart' as login_screen;
import 'package:sinaliza_app_libras/views/profile_page.dart';

class CombinedLessonData {
  final List<Map<String, dynamic>> lessons;
  final Set<int> completedLessonIds;
  CombinedLessonData({required this.lessons, required this.completedLessonIds});
}

class LessonListScreen extends StatefulWidget {
  final int? moduleId;
  final String? moduleTitle;

  const LessonListScreen({super.key, this.moduleId, this.moduleTitle});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  final _storage = const FlutterSecureStorage();
  late Future<CombinedLessonData> _dataFuture;

  // Paleta Neon e Gradiente
  static const Color darkBG = Color(0xFF02040A); // Começo do degradê
  static const Color darkBG2 = Color(0xFF020915); // Fim do degradê
  static const Color cardDark = Color(0xFF07101F);
  static const Color neonGreen = Color(0xFF00FF9D);
  static const Color neonPurple = Color(0xFF7A5CFF);

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
      throw Exception('Token não encontrado. Fazendo logout.');
    }

    // ATENÇÃO: Ajuste o IP conforme necessário
    const String baseUrl = 'http://26.72.151.39:3000';
    final headers = {'Authorization': 'Bearer $token'};

    try {
      // Constrói URL com filtro
      String lessonsUrl = '$baseUrl/lessons';
      if (widget.moduleId != null) {
        lessonsUrl += '?module_id=${widget.moduleId}';
      }

      final responses = await Future.wait([
        http.get(Uri.parse(lessonsUrl), headers: headers),
        http.get(Uri.parse('$baseUrl/progress'), headers: headers),
      ]);

      if (responses[0].statusCode != 200) throw Exception('Erro ao carregar lições');
      if (responses[1].statusCode != 200) throw Exception('Erro ao carregar progresso');

      final lessons = (json.decode(responses[0].body) as List).cast<Map<String, dynamic>>();
      final progress = json.decode(responses[1].body);

      final completedIds = progress
          .map<int>((p) => p['lesson_id'] as int)
          .toSet();

      return CombinedLessonData(
        lessons: lessons,
        completedLessonIds: completedIds,
      );
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  void _logout() async {
    await _storage.delete(key: 'jwt_token');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const login_screen.LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removemos backgroundColor sólido para usar Container com gradiente
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [darkBG, darkBG2], // O degradê que você pediu
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ---------------- HEADER CUSTOMIZADO ----------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo e Título "SINALIZA"
                    Row(
                      children: const [
                        Icon(Icons.waving_hand_outlined, color: neonGreen, size: 28),
                        SizedBox(width: 10),
                        Text(
                          "SINALIZA",
                          style: TextStyle(
                            color: neonGreen,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    
                    // Botão de Perfil
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.person, color: Colors.white),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfilePage()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Subtítulo do Módulo (Opcional, para saber onde estamos)
              if (widget.moduleTitle != null)
                Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.moduleTitle!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              // ---------------- LISTA DE LIÇÕES ----------------
              Expanded(
                child: FutureBuilder<CombinedLessonData>(
                  future: _dataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: neonGreen),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: Text(
                          'Nenhuma lição encontrada.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    final lessons = snapshot.data!.lessons;
                    final completed = snapshot.data!.completedLessonIds;
                    
                    if (lessons.isEmpty) {
                       return const Center(
                        child: Text(
                          'Nenhuma lição neste módulo.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: lessons.length,
                      itemBuilder: (context, index) {
                        final lesson = lessons[index];
                        final bool isDone = completed.contains(lesson["id"]);

                        return GestureDetector(
                          onTap: () async {
                            // Vai para a INSTRUÇÃO primeiro
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LessonInstructionScreen(lesson: lesson),
                              ),
                            );
                            // Atualiza ao voltar
                            if (mounted) _refreshData();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 18),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardDark,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDone ? neonGreen : neonPurple.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDone ? neonGreen : neonPurple).withValues(alpha: 0.1),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Ícone de Status (Estrela ou Cadeado/Mão)
                                Icon(
                                  isDone ? Icons.star : Icons.front_hand, // Troquei cadeado por mão se não feito
                                  color: isDone ? neonGreen : neonPurple,
                                  size: 28,
                                ),
                                const SizedBox(width: 16),
                                
                                // Textos
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lesson["title"],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        lesson["description"] ?? "",
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Seta
                                if (!isDone)
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.white.withValues(alpha: 0.3),
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      // Botão flutuante
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshData,
        backgroundColor: neonGreen,
        foregroundColor: darkBG,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}