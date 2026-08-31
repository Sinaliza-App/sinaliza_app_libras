import 'package:flutter/material.dart';
import 'package:sinaliza_app_libras/services/api_service.dart';
import 'dart:convert';

import 'package:sinaliza_app_libras/views/lesson_instruction_screen.dart';
import 'package:sinaliza_app_libras/theme/app_colors.dart';
import 'package:sinaliza_app_libras/widgets/animations/fade_in_slide.dart';
import 'package:flutter/services.dart';
import 'package:sinaliza_app_libras/views/profile_page.dart';
import 'package:sinaliza_app_libras/constants.dart';
import 'package:provider/provider.dart';
import 'package:sinaliza_app_libras/providers/user_provider.dart';
import 'package:sinaliza_app_libras/views/challenge_sequence_screen.dart';
import 'package:sinaliza_app_libras/widgets/custom_snackbar.dart';

class CombinedLessonData {
  final List<Map<String, dynamic>> lessons;
  final Set<int> completedLessonIds;
  CombinedLessonData({required this.lessons, required this.completedLessonIds});
}

class LessonListScreen extends StatefulWidget {
  final int? moduleId;
  final String? moduleTitle;
  final String? iconName;

  const LessonListScreen({super.key, this.moduleId, this.moduleTitle, this.iconName});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
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
    final String baseUrl = apiBaseUrl;

    try {
      String lessonsUrl = '$baseUrl/lessons';
      if (widget.moduleId != null) {
        lessonsUrl += '?module_id=${widget.moduleId}';
      }

      final responses = await Future.wait([
        ApiService.get(lessonsUrl),
        ApiService.get('$baseUrl/progress'),
      ]);

      if (responses[0].statusCode != 200) {
        throw Exception('Erro ao carregar lições');
      }
      if (responses[1].statusCode != 200) {
        throw Exception('Erro ao carregar progresso');
      }

      final lessons = (json.decode(responses[0].body) as List)
          .cast<Map<String, dynamic>>();
      final progress = json.decode(responses[1].body) as List<dynamic>;

      final completedIds = progress
          .map<int>((dynamic p) => p['lesson_id'] as int)
          .toSet();

      return CombinedLessonData(
        lessons: lessons,
        completedLessonIds: completedIds,
      );
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }



  // Lógica visual para combinar com a tela anterior
  Color _getModuleColor() {
    final colors = [
      AppColors.neonGreen,
      AppColors.neonPurple,
      AppColors.neonBlue,
      AppColors.neonOrange,
    ];
    int index = (widget.moduleId ?? 1) - 1;
    if (index < 0) index = 0;
    return colors[index % colors.length];
  }

  IconData _getModuleIcon() {
    // 1. Tenta usar o nome do ícone vindo diretamente do banco de dados (mais seguro)
    switch (widget.iconName) {
      case 'alphabet': return Icons.sort_by_alpha;
      case 'numbers': return Icons.filter_1;
      case 'day by day': return Icons.waving_hand;
      case 'day to day': return Icons.waving_hand;
      case 'family': return Icons.family_restroom;
      case 'colors': return Icons.palette;
      case 'animals': return Icons.pets;
      case 'verbs': return Icons.run_circle_outlined;
    }

    // 2. Se falhar, adivinha pelo título (fallback)
    final title = (widget.moduleTitle ?? "").toLowerCase();
    if (title.contains('alphabet') || title.contains('alfabeto')) return Icons.sort_by_alpha;
    if (title.contains('day to day') || title.contains('day by day') || title.contains('dia a dia')) return Icons.waving_hand;
    if (title.contains('colors') || title.contains('core')) return Icons.palette;
    if (title.contains('animals') || title.contains('animai')) return Icons.pets;
    if (title.contains('verbs') || title.contains('verbo')) return Icons.run_circle_outlined;
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
            colors: [AppColors.darkBG, AppColors.darkBG2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ---------------- HEADER CUSTOMIZADO ----------------
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
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
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    // Botão de Perfil
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.neonBlue.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<dynamic>(
                            builder: (_) => const ProfilePage(),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Consumer<UserProvider>(
                            builder: (context, userProvider, child) {
                              final user = userProvider.user;
                              if (user != null &&
                                  user.profilePicture != null &&
                                  user.profilePicture!.isNotEmpty) {
                                ImageProvider imageProvider;
                                if (user.profilePicture!.startsWith('http')) {
                                  imageProvider = NetworkImage(user.profilePicture!);
                                } else {
                                  String base64Str = user.profilePicture!;
                                  if (base64Str.contains(',')) base64Str = base64Str.split(',').last;
                                  base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');
                                  while (base64Str.length % 4 != 0) {
                                    base64Str += '=';
                                  }
                                  imageProvider = MemoryImage(base64Decode(base64Str));
                                }
                                return CircleAvatar(
                                  radius: 18,
                                  backgroundImage: imageProvider,
                                );
                              } else {
                                return const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.transparent,
                                  child: Icon(Icons.person, color: Colors.white),
                                );
                              }
                            },
                          ),
                        ),
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
                    tag:
                        'module_icon_${widget.moduleId}', // MESMA TAG DA TELA ANTERIOR
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
                          ),
                        ],
                      ),
                      child: Icon(moduleIcon, size: 40, color: moduleColor),
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
                        Shadow(
                          color: moduleColor.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
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
                        child: CircularProgressIndicator(color: AppColors.neonGreen),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      itemCount: lessons.length + 1, // +1 para o Desafio Final
                      itemBuilder: (context, index) {
                        if (index == lessons.length) {
                          // CARD DO DESAFIO FINAL (BOSS)
                          final bool isBossUnlocked = lessons.every((l) => completed.contains(l["id"]));
                          
                          return FadeInSlide(
                            duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
                            yOffset: 20.0,
                            child: GestureDetector(
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                if (isBossUnlocked) {
                                  // Abre o Desafio Sequencial com as lições deste módulo
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute<dynamic>(
                                      builder: (context) => ChallengeSequenceScreen(lessons: lessons.where((l) => l["is_draft"] != true).toList()),
                                    ),
                                  );
                                  if (mounted) _refreshData();
                                } else {
                                  CustomSnackBar.showWarning(context, "Conclua todas as lições acima para desbloquear!");
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(top: 20, bottom: 40),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: isBossUnlocked
                                      ? const LinearGradient(colors: [Colors.orange, Colors.deepOrange])
                                      : LinearGradient(colors: [Colors.grey[800]!, Colors.grey[900]!]),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isBossUnlocked ? Colors.yellow : Colors.grey[700]!,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    if (isBossUnlocked)
                                      BoxShadow(
                                        color: Colors.orange.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isBossUnlocked ? Icons.local_fire_department_rounded : Icons.lock_rounded,
                                      color: isBossUnlocked ? Colors.yellow : Colors.grey[500],
                                      size: 40,
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Desafio Final",
                                            style: TextStyle(
                                              color: isBossUnlocked ? Colors.white : Colors.grey[400],
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            isBossUnlocked 
                                                ? "Prove que domina o módulo!" 
                                                : "Bloqueado",
                                            style: TextStyle(
                                              color: isBossUnlocked ? Colors.white.withValues(alpha: 0.9) : Colors.grey[500],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        final lesson = lessons[index];
                        final bool isDone = completed.contains(lesson["id"]);
                        final bool isDraft = lesson["is_draft"] == true;

                        return FadeInSlide(
                          duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
                          yOffset: 20.0,
                          child: GestureDetector(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await Navigator.push(
                                context,
                                MaterialPageRoute<dynamic>(
                                  builder: (context) =>
                                      LessonInstructionScreen(lesson: lesson),
                                ),
                              );
                              if (mounted) _refreshData();
                            },
                            child: Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(bottom: 18),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardDark,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isDone
                                          ? AppColors.neonGreen
                                          : (isDraft ? Colors.amber : AppColors.neonPurple.withValues(alpha: 0.3)),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isDone ? AppColors.neonGreen : (isDraft ? Colors.amber : AppColors.neonPurple))
                                            .withValues(alpha: 0.1),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isDone ? Icons.star : Icons.front_hand,
                                        color: isDone ? AppColors.neonGreen : (isDraft ? Colors.amber : AppColors.neonPurple),
                                        size: 32,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    lesson["title"] as String,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              (lesson["description"] as String?) ??
                                                  "Toque para começar",
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.6,
                                                ),
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
                                if (isDraft)
                                  Positioned(
                                    top: 0,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        "RASCUNHO",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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
        backgroundColor: AppColors.neonGreen,
        foregroundColor: AppColors.darkBG,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
