import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/lesson_instruction_screen.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart' as login_screen;
import 'package:sinaliza_app_libras/views/profile_page.dart';
import 'package:sinaliza_app_libras/constants.dart';

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
  static const Color darkBG = Color(0xFF02040A);
  static const Color darkBG2 = Color.fromARGB(255, 7, 19, 44);
  static const Color cardDark = Color(0xFF07101F);
  static const Color neonGreen = Color(0xFF00FF9D);
  static const Color neonPurple = Color(0xFF7A5CFF);
  static const Color neonBlue = Color(0xFF00D1FF);
  static const Color neonOrange = Color(0xFFFF9900);

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

    const String baseUrl = apiBaseUrl;
    final headers = {'Authorization': 'Bearer $token'};

    try {
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

  // Lógica visual para combinar com a tela anterior
  Color _getModuleColor() {
    // Usa o ID para manter a cor consistente com a lista de módulos
    final colors = [neonGreen, const Color.fromARGB(255, 99, 65, 255), neonBlue, neonOrange];
    int index = (widget.moduleId ?? 1) - 1; 
    if (index < 0) index = 0;
    return colors[index % colors.length];
  }

  IconData _getModuleIcon() {
    // Tenta adivinhar o ícone pelo título já que não recebemos o icon_name aqui
    final title = (widget.moduleTitle ?? "").toLowerCase();
    if (title.contains('alfabeto')) return Icons.sort_by_alpha;
    if (title.contains('número') || title.contains('numero')) return Icons.filter_1;
    if (title.contains('sauda')) return Icons.waving_hand;
    return Icons.class_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final moduleColor = _getModuleColor();
    final moduleIcon = _getModuleIcon();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [darkBG, darkBG2],
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
                    // Botão Voltar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
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
                        tooltip: 'Perfil',
                      ),
                    ),
                  ],
                ),
              ),
              
              // --- HERO ANIMATION (A MÁGICA ACONTECE AQUI) ---
              // Este ícone vai "voar" da tela anterior para cá
              if (widget.moduleId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Hero(
                    tag: 'module_icon_${widget.moduleId}', // MESMA TAG DA TELA ANTERIOR
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: moduleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: moduleColor.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ]
                      ),
                      child: Icon(
                        moduleIcon,
                        size: 40,
                        color: moduleColor,
                      ),
                    ),
                  ),
                ),
              // ------------------------------------------------

              // Título do Módulo
              if (widget.moduleTitle != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    widget.moduleTitle!.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: moduleColor.withValues(alpha: 0.5), blurRadius: 10)
                      ]
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
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LessonInstructionScreen(lesson: lesson),
                              ),
                            );
                            if (mounted) _refreshData();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 18),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardDark,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDone ? neonGreen : neonPurple.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDone ? neonGreen : neonPurple).withValues(alpha: 0.1),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isDone ? Icons.star : Icons.front_hand,
                                  color: isDone ? neonGreen : neonPurple,
                                  size: 32,
                                ),
                                const SizedBox(width: 16),
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
                                        lesson["description"] ?? "Toque para começar",
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
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshData,
        backgroundColor: neonGreen,
        foregroundColor: darkBG,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}