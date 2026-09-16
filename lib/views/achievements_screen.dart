import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';

import 'package:sinaliza_app_libras/providers/user_provider.dart';
import 'package:sinaliza_app_libras/services/api_service.dart';
import 'package:sinaliza_app_libras/constants.dart';
import 'package:sinaliza_app_libras/theme/app_colors.dart';
import 'package:sinaliza_app_libras/widgets/animations/fade_in_slide.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;
  
  int _totalUnlocked = 0;
  int _userXp = 0;
  int _userStreak = 0;
  int _completedLessons = 0;
  bool _isLoading = true;

  // Sistema de conquistas expandido
  static final List<Map<String, dynamic>> _allBadges = [
    // --- Conquistas de XP (Nível) ---
    {
      'id': 'xp_beginner',
      'title': 'Aprendiz',
      'description': 'Seus primeiros passos em Libras!',
      'icon': Icons.star_rounded,
      'color': AppColors.neonBlue,
      'category': 'XP',
      'requirement': 10,
      'requirementType': 'xp',
    },
    {
      'id': 'xp_curious',
      'title': 'Curioso',
      'description': 'A curiosidade é o motor da sabedoria.',
      'icon': Icons.visibility,
      'color': AppColors.neonGreen,
      'category': 'XP',
      'requirement': 100,
      'requirementType': 'xp',
    },
    {
      'id': 'xp_dedicated',
      'title': 'Dedicado',
      'description': 'Sua dedicação está se mostrando!',
      'icon': Icons.local_fire_department_rounded,
      'color': AppColors.neonRed,
      'category': 'XP',
      'requirement': 300,
      'requirementType': 'xp',
    },
    {
      'id': 'xp_advanced',
      'title': 'Avançado',
      'description': 'Poucos chegam tão longe. Parabéns!',
      'icon': Icons.workspace_premium_rounded,
      'color': Colors.amber,
      'category': 'XP',
      'requirement': 600,
      'requirementType': 'xp',
    },
    {
      'id': 'xp_master',
      'title': 'Mestre',
      'description': 'Domínio absoluto da Língua de Sinais!',
      'icon': Icons.diamond_rounded,
      'color': Colors.purpleAccent,
      'category': 'XP',
      'requirement': 1100,
      'requirementType': 'xp',
    },
    // --- Conquistas de Ofensiva (Streak) ---
    {
      'id': 'streak_3',
      'title': 'Constante',
      'description': '3 dias seguidos de estudo!',
      'icon': Icons.bolt_rounded,
      'color': AppColors.neonOrange,
      'category': 'Ofensiva',
      'requirement': 3,
      'requirementType': 'streak',
    },
    {
      'id': 'streak_7',
      'title': 'Semana Perfeita',
      'description': '7 dias sem parar. Impressionante!',
      'icon': Icons.whatshot_rounded,
      'color': AppColors.neonOrange,
      'category': 'Ofensiva',
      'requirement': 7,
      'requirementType': 'streak',
    },
    {
      'id': 'streak_30',
      'title': 'Imparável',
      'description': '30 dias de ofensiva! Você é lendário.',
      'icon': Icons.auto_awesome_rounded,
      'color': AppColors.neonGold,
      'category': 'Ofensiva',
      'requirement': 30,
      'requirementType': 'streak',
    },
    // --- Conquistas de Progresso (Lições completadas) ---
    {
      'id': 'lessons_1',
      'title': 'Primeiro Sinal',
      'description': 'Completou sua primeira lição.',
      'icon': Icons.back_hand_rounded,
      'color': AppColors.neonGreen,
      'category': 'Progresso',
      'requirement': 1,
      'requirementType': 'lessons',
    },
    {
      'id': 'lessons_5',
      'title': 'Estudante',
      'description': '5 lições no currículo. Continue!',
      'icon': Icons.school_rounded,
      'color': AppColors.neonBlue,
      'category': 'Progresso',
      'requirement': 5,
      'requirementType': 'lessons',
    },
    {
      'id': 'lessons_15',
      'title': 'Dicionarista',
      'description': 'Dominou 15 sinais de Libras!',
      'icon': Icons.menu_book_rounded,
      'color': Colors.tealAccent,
      'category': 'Progresso',
      'requirement': 15,
      'requirementType': 'lessons',
    },
    {
      'id': 'lessons_30',
      'title': 'Enciclopédia',
      'description': '30 lições! Você é uma referência.',
      'icon': Icons.auto_stories_rounded,
      'color': AppColors.neonGold,
      'category': 'Progresso',
      'requirement': 30,
      'requirementType': 'lessons',
    },
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutBack,
    );
    _fetchAchievementData();
    _headerController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  Future<void> _fetchAchievementData() async {
    try {
      final response = await ApiService.get('$apiBaseUrl/users/me');
      if (response.statusCode == 200 && mounted) {
        final userData = json.decode(response.body);
        final xp = int.tryParse(userData['total_score']?.toString() ?? '0') ?? 0;
        final streak = int.tryParse(userData['streak_count']?.toString() ?? '0') ?? 0;

        // Buscar lições completadas
        final progressResponse = await ApiService.get('$apiBaseUrl/modules');
        int totalCompleted = 0;
        if (progressResponse.statusCode == 200) {
          final modules = json.decode(progressResponse.body) as List;
          for (final m in modules) {
            totalCompleted += (int.tryParse(m['completed_lessons']?.toString() ?? '0') ?? 0);
          }
        }

        if (mounted) {
          setState(() {
            _userXp = xp;
            _userStreak = streak;
            _completedLessons = totalCompleted;
            _totalUnlocked = _allBadges.where((b) => _isBadgeUnlocked(b)).length;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Erro ao carregar conquistas: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isBadgeUnlocked(Map<String, dynamic> badge) {
    final type = badge['requirementType'] as String;
    final req = badge['requirement'] as int;
    switch (type) {
      case 'xp':
        return _userXp >= req;
      case 'streak':
        return _userStreak >= req;
      case 'lessons':
        return _completedLessons >= req;
      default:
        return false;
    }
  }

  String _getProgressText(Map<String, dynamic> badge) {
    final type = badge['requirementType'] as String;
    final req = badge['requirement'] as int;
    switch (type) {
      case 'xp':
        return '$_userXp / $req XP';
      case 'streak':
        return '$_userStreak / $req dias';
      case 'lessons':
        return '$_completedLessons / $req lições';
      default:
        return '';
    }
  }

  double _getProgressValue(Map<String, dynamic> badge) {
    final type = badge['requirementType'] as String;
    final req = badge['requirement'] as int;
    double current;
    switch (type) {
      case 'xp':
        current = _userXp.toDouble();
        break;
      case 'streak':
        current = _userStreak.toDouble();
        break;
      case 'lessons':
        current = _completedLessons.toDouble();
        break;
      default:
        current = 0;
    }
    return (current / req).clamp(0.0, 1.0);
  }

  void _showBadgeDetails(Map<String, dynamic> badge) {
    final bool isUnlocked = _isBadgeUnlocked(badge);
    final Color badgeColor = badge['color'] as Color;

    if (isUnlocked) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, a1, a2, widget) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(a1.value),
          child: Opacity(opacity: a1.value, child: widget),
        );
      },
      pageBuilder: (context, a1, a2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.82,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isUnlocked
                      ? badgeColor.withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.2),
                  width: 2,
                ),
                boxShadow: isUnlocked
                    ? [
                        BoxShadow(
                          color: badgeColor.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícone grande
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isUnlocked ? badgeColor : Colors.grey).withValues(alpha: 0.15),
                      border: Border.all(
                        color: (isUnlocked ? badgeColor : Colors.grey).withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      badge['icon'] as IconData,
                      color: isUnlocked ? badgeColor : Colors.grey.shade700,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? badgeColor.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isUnlocked ? '✨ DESBLOQUEADA' : '🔒 BLOQUEADA',
                      style: TextStyle(
                        color: isUnlocked ? badgeColor : Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Título
                  Text(
                    badge['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Descrição
                  Text(
                    badge['description'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Barra de progresso
                  if (!isUnlocked) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _getProgressValue(badge),
                        backgroundColor: Colors.grey.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getProgressText(badge),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Categoria
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category_rounded, color: Colors.grey.shade600, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Categoria: ${badge['category']}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    final int xp = user?.totalScore ?? _userXp;

    // Agrupar badges por categoria
    final categories = <String, List<Map<String, dynamic>>>{};
    for (final badge in _allBadges) {
      final cat = badge['category'] as String;
      categories.putIfAbsent(cat, () => []);
      categories[cat]!.add(badge);
    }

    return Scaffold(
      backgroundColor: AppColors.darkBG,
      body: Stack(
        children: [
          // Background gradients decorativos
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.neonGreen.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.neonPurple.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Conteúdo principal
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // AppBar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Conquistas',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // Para centralizar
                      ],
                    ),
                  ),
                ),

                // Header com progresso geral
                SliverToBoxAdapter(
                  child: ScaleTransition(
                    scale: _headerAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.neonGreen.withValues(alpha: 0.15),
                              AppColors.neonBlue.withValues(alpha: 0.1),
                              AppColors.neonPurple.withValues(alpha: 0.08),
                            ],
                          ),
                          border: Border.all(
                            color: AppColors.neonGreen.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonGreen.withValues(alpha: 0.1),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.emoji_events_rounded,
                                    color: AppColors.neonGold, size: 28),
                                const SizedBox(width: 10),
                                Text(
                                  '$_totalUnlocked / ${_allBadges.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Conquistas Desbloqueadas',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Barra de progresso geral
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: _totalUnlocked / _allBadges.length),
                                duration: const Duration(milliseconds: 1500),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonGreen),
                                    minHeight: 10,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Resumo rápido
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildMiniStat(Icons.bolt_rounded, '$xp XP', AppColors.neonBlue),
                                _buildMiniStat(Icons.local_fire_department_rounded,
                                    '$_userStreak dias', AppColors.neonOrange),
                                _buildMiniStat(Icons.check_circle_rounded,
                                    '$_completedLessons lições', AppColors.neonGreen),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Loading ou conteúdo
                if (_isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.neonGreen),
                    ),
                  )
                else
                  // Seções por categoria
                  ...categories.entries.expand((entry) {
                    final categoryName = entry.key;
                    final badges = entry.value;
                    final IconData catIcon;
                    final Color catColor;
                    
                    switch (categoryName) {
                      case 'XP':
                        catIcon = Icons.star_rounded;
                        catColor = AppColors.neonBlue;
                        break;
                      case 'Ofensiva':
                        catIcon = Icons.local_fire_department_rounded;
                        catColor = AppColors.neonOrange;
                        break;
                      case 'Progresso':
                        catIcon = Icons.school_rounded;
                        catColor = AppColors.neonGreen;
                        break;
                      default:
                        catIcon = Icons.category_rounded;
                        catColor = Colors.grey;
                    }

                    return [
                      // Título da categoria
                      SliverToBoxAdapter(
                        child: FadeInSlide(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(catIcon, color: catColor, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  categoryName.toUpperCase(),
                                  style: TextStyle(
                                    color: catColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: catColor.withValues(alpha: 0.2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Grid de badges da categoria
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final badge = badges[index];
                              return _buildBadgeCard(badge);
                            },
                            childCount: badges.length,
                          ),
                        ),
                      ),
                      // Espaço entre categorias
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ];
                  }),

                // Espaço final
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),

          // Confetes
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppColors.neonGreen,
                AppColors.neonBlue,
                AppColors.neonGold,
                AppColors.neonPurple,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade300,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge) {
    final bool isUnlocked = _isBadgeUnlocked(badge);
    final Color badgeColor = badge['color'] as Color;
    final double progress = _getProgressValue(badge);

    return FadeInSlide(
      child: GestureDetector(
        onTap: () => _showBadgeDetails(badge),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUnlocked
                  ? badgeColor.withValues(alpha: 0.5)
                  : Colors.grey.withValues(alpha: 0.15),
              width: isUnlocked ? 2 : 1,
            ),
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow de fundo para badges desbloqueadas
              if (isUnlocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: RadialGradient(
                        colors: [
                          badgeColor.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Conteúdo
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ícone
                    Icon(
                      badge['icon'] as IconData,
                      color: isUnlocked
                          ? badgeColor
                          : Colors.grey.withValues(alpha: 0.25),
                      size: 34,
                    ),
                    const SizedBox(height: 8),
                    // Título
                    Text(
                      badge['title'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isUnlocked
                            ? Colors.white
                            : Colors.grey.withValues(alpha: 0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Mini barra de progresso
                    SizedBox(
                      width: 50,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isUnlocked ? badgeColor : Colors.grey.shade700,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Ícone de cadeado
              if (!isUnlocked)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.lock_rounded,
                    color: Colors.grey.withValues(alpha: 0.3),
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
