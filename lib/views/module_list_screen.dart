import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/lesson_list_screen.dart';
import 'package:sinaliza_app_libras/views/profile_page.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';
import 'package:sinaliza_app_libras/constants.dart';
import 'package:sinaliza_app_libras/theme/app_colors.dart';
import 'package:sinaliza_app_libras/widgets/animations/fade_in_slide.dart';
import 'package:sinaliza_app_libras/widgets/animations/neon_pulse.dart';
import 'package:flutter/services.dart';
import 'package:sinaliza_app_libras/views/ranking_screen.dart';
import 'package:sinaliza_app_libras/views/dictionary_screen.dart';
import 'package:sinaliza_app_libras/views/quiz_screen.dart';
import 'package:provider/provider.dart';
import 'package:sinaliza_app_libras/providers/user_provider.dart';

class ModuleListScreen extends StatefulWidget {
  const ModuleListScreen({super.key});

  @override
  State<ModuleListScreen> createState() => _ModuleListScreenState();
}

class _ModuleListScreenState extends State<ModuleListScreen> {
  final _storage = const FlutterSecureStorage();
  late Future<List<Map<String, dynamic>>> _modulesFuture;

  @override
  void initState() {
    super.initState();
    _refreshModules();
  }

  void _refreshModules() {
    setState(() {
      _modulesFuture = _fetchModules();
    });
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        if (userData['total_score'] != null) {
          userData['total_score'] = int.tryParse(userData['total_score'].toString()) ?? 0;
        }
        if (mounted) {
          Provider.of<UserProvider>(context, listen: false).setUser(userData);
        }
      }
    } catch (e) {
      debugPrint("Erro ao carregar dados do usuário na main: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchModules() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      _logout();
      throw Exception('Token não encontrado');
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/modules'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        if (response.statusCode == 401) _logout();
        throw Exception('Erro ao carregar módulos');
      }
    } catch (e) {
      debugPrint("Erro de conexão: $e");
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

  IconData _getModuleIcon(String? iconName) {
    switch (iconName) {
      case 'alphabet':
        return Icons.sort_by_alpha;
      case 'day to day':
        return Icons.waving_hand;
      case 'colors':
        return Icons.palette;
      case 'animals':
        return Icons.pets;
      case 'verbs':
        return Icons.run_circle_outlined;
      default:
        return Icons.class_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
              // ---------------- HEADER LIMPO ----------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ESQUERDA: Logo
                    Row(
                      children: const [
                        Icon(Icons.waving_hand_outlined, color: AppColors.neonGreen, size: 26),
                        SizedBox(width: 8),
                        Text(
                          'SINALIZA',
                          style: TextStyle(
                            color: AppColors.neonGreen,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),

                    // DIREITA: Ofensiva + Foto de Perfil
                    Row(
                      children: [
                        // Ofensiva (Foguinho)
                        Consumer<UserProvider>(
                          builder: (context, userProvider, child) {
                            final user = userProvider.user;
                            final int streak = user?.streakCount ?? 0;
                            final bool isLit = streak > 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isLit
                                    ? AppColors.neonOrange.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isLit
                                      ? AppColors.neonOrange.withValues(alpha: 0.5)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department_rounded,
                                    color: isLit ? AppColors.neonOrange : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$streak',
                                    style: TextStyle(
                                      color: isLit ? AppColors.neonOrange : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        // Foto de Perfil
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfilePage()),
                          ).then((_) {
                            if (mounted) _refreshModules();
                          }),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.neonBlue.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                            child: Consumer<UserProvider>(
                              builder: (context, userProvider, child) {
                                final user = userProvider.user;
                                if (user != null &&
                                    user.profilePicture != null &&
                                    user.profilePicture!.isNotEmpty) {
                                  final Uint8List? imageBytes = () {
                                    try {
                                      String base64Str = user.profilePicture!;
                                      if (base64Str.contains(',')) {
                                        base64Str = base64Str.split(',').last;
                                      }
                                      base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');
                                      while (base64Str.length % 4 != 0) {
                                        base64Str += '=';
                                      }
                                      return base64Decode(base64Str);
                                    } catch (e) {
                                      return null;
                                    }
                                  }();
                                  if (imageBytes != null) {
                                    return CircleAvatar(
                                      radius: 18,
                                      backgroundImage: MemoryImage(imageBytes),
                                    );
                                  }
                                }
                                return const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.transparent,
                                  child: Icon(Icons.person, color: Colors.white),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // ---------------- LISTA DE MÓDULOS ----------------
              Expanded(child: _buildModulesList()),
            ],
          ),
        ),
      ),
      // ---------------- BOTTOM NAVIGATION BAR ----------------
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          onTap: (index) {
            if (index == 0) return;
            final screens = <Widget>[
              const SizedBox(), // placeholder
              const DictionaryScreen(),
              const QuizScreen(),
              const RankingScreen(),
            ];
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => screens[index]),
            ).then((_) {
              if (mounted) _refreshModules();
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.cardDark,
          selectedItemColor: AppColors.neonGreen,
          unselectedItemColor: Colors.white38,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.school_rounded),
              label: 'Módulos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded),
              label: 'Dicionário',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.quiz_rounded),
              label: 'Quiz',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_rounded),
              label: 'Ranking',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModulesList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _modulesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.neonGreen),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Erro ao carregar módulos',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                TextButton(
                  onPressed: _refreshModules,
                  child: const Text('Tentar Novamente', style: TextStyle(color: AppColors.neonGreen)),
                ),
              ],
            ),
          );
        }

        final modules = snapshot.data!;
        if (modules.isEmpty) {
          return const Center(
            child: Text('Nenhum módulo encontrado.', style: TextStyle(color: Colors.white70)),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _refreshModules(),
          color: AppColors.neonGreen,
          backgroundColor: AppColors.cardDark,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final module = modules[index];
              final color = [AppColors.neonGreen, AppColors.neonPurple, AppColors.neonBlue, AppColors.neonOrange][index % 4];
              final icon = _getModuleIcon(module['icon_name']);

              final int total = module['total_lessons'] ?? 0;
              final int completed = module['completed_lessons'] ?? 0;
              final double progress = total == 0 ? 0.0 : (completed / total);
              final String progressText = "${(progress * 100).toInt()}%";

              return FadeInSlide(
                duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
                yOffset: 20.0,
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LessonListScreen(
                          moduleId: module['id'],
                          moduleTitle: module['title'],
                          iconName: module['icon_name'],
                        ),
                      ),
                    );
                    if (mounted) _refreshModules();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          // Ícone com Hero
                          Hero(
                            tag: 'module_icon_${module['id']}',
                            child: progress == 1.0
                                ? NeonPulse(neonColor: color, child: _buildIconContainer(icon, color))
                                : _buildIconContainer(icon, color),
                          ),
                          const SizedBox(width: 20),
                          // Textos
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "MÓDULO ${index + 1}",
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  module['title'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.grey[900],
                                      color: color,
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                                Text(
                                  "$completed de $total lições ($progressText)",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white.withValues(alpha: 0.3),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildIconContainer(IconData icon, Color color) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 35),
    );
  }
}
