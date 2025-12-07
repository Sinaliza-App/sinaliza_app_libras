import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/lesson_list_screen.dart';
import 'package:sinaliza_app_libras/views/profile_page.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';
import 'package:sinaliza_app_libras/constants.dart';
import 'package:sinaliza_app_libras/views/ranking_screen.dart';

class ModuleListScreen extends StatefulWidget {
  const ModuleListScreen({super.key});

  @override
  State<ModuleListScreen> createState() => _ModuleListScreenState();
}

class _ModuleListScreenState extends State<ModuleListScreen> {
  final _storage = const FlutterSecureStorage();
  late Future<List<Map<String, dynamic>>> _modulesFuture;

  // Cores do Tema (Iguais às da LessonListScreen)
  static const Color neonGreen = Color(0xFF00FF9D);
  static const Color neonPurple = Color(0xFF7A5CFF);
  static const Color neonBlue = Color(0xFF00D1FF);
  static const Color neonOrange = Color(0xFFFF9900);

  // --- CORES DO DEGRADÊ (IDÊNTICAS AO SEU CÓDIGO) ---
  static const Color darkBG = Color(0xFF02040A); // Começo do degradê
  static const Color darkBG2 = Color.fromARGB(255, 7, 19, 44); // Fim do degradê
  static const Color cardDark = Color(0xFF07101F);

  @override
  void initState() {
    super.initState();
    _refreshModules();
  }

  void _refreshModules() {
    setState(() {
      _modulesFuture = _fetchModules();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchModules() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      _logout();
      throw Exception('Token não encontrado');
    }

    // ATENÇÃO: Ajuste o IP conforme necessário
    const String baseUrl = apiBaseUrl;

    try {
      debugPrint("Tentando buscar módulos em: $baseUrl/modules");
      final response = await http.get(
        Uri.parse('$baseUrl/modules'),
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
      debugPrint("Erro de conexão EXATO: $e");
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
      case 'numbers':
        return Icons.filter_1;
      case 'greetings':
        return Icons.waving_hand;
      default:
        return Icons.class_outlined;
    }
  }

  Color _getModuleColor(int index) {
    final colors = [neonGreen, neonPurple, neonBlue, neonOrange];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fundo com Degradê VERTICAL (Igual ao da LessonListScreen)
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
              // ---------------- HEADER CORRIGIDO ----------------
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 1. LADO ESQUERDO: Logo e Nome
                    Row(
                      children: const [
                        Icon(
                          Icons.waving_hand_outlined,
                          color: neonGreen,
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'SINALIZA',
                          style: TextStyle(
                            color: neonGreen,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),

                    // 2. LADO DIREITO: Ícones Agrupados (Troféu + Perfil)
                    Row(
                      children: [
                        // Botão de Ranking (Troféu)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.emoji_events,
                              color: Color(0xFFFFD700), // Dourado
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RankingScreen(),
                              ),
                            ),
                            tooltip: 'Ranking Global',
                          ),
                        ),

                        const SizedBox(width: 12), // Espaço entre os ícones

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
                              MaterialPageRoute(
                                builder: (c) => const ProfilePage(),
                              ),
                            ),
                            tooltip: 'Perfil',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ---------------- LISTA DE MÓDULOS ----------------
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _modulesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: neonGreen),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Erro ao carregar módulos',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            TextButton(
                              onPressed: _refreshModules,
                              child: const Text(
                                'Tentar Novamente',
                                style: TextStyle(color: neonGreen),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final modules = snapshot.data!;

                    if (modules.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhum módulo encontrado.',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: modules.length,
                      itemBuilder: (context, index) {
                        final module = modules[index];
                        final color = _getModuleColor(index);
                        final icon = _getModuleIcon(module['icon_name']);

                        // CÁLCULO DO PROGRESSO (Mantido)
                        final int total = module['total_lessons'] ?? 0;
                        final int completed = module['completed_lessons'] ?? 0;
                        final double progress = total == 0
                            ? 0.0
                            : (completed / total);
                        final String progressText =
                            "${(progress * 100).toInt()}%";

                        // Lógica de bloqueio
                        final bool isLocked = index > 0 && progress == 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: cardDark,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isLocked
                                  ? Colors.grey.withValues(alpha: 0.3)
                                  : color.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isLocked
                                    ? Colors.black
                                    : color.withValues(alpha: 0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: isLocked
                                  ? null
                                  : () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              LessonListScreen(
                                                moduleId: module['id'],
                                                moduleTitle: module['title'],
                                              ),
                                        ),
                                      );
                                      if (mounted) _refreshModules();
                                    },
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Row(
                                  children: [
                                    // Ícone Grande
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: isLocked
                                            ? Colors.grey.withValues(alpha: 0.1)
                                            : color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        isLocked ? Icons.lock : icon,
                                        color: isLocked ? Colors.grey : color,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 20),

                                    // Textos e Barra de Progresso
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "MÓDULO ${index + 1}",
                                            style: TextStyle(
                                              color: isLocked
                                                  ? Colors.grey
                                                  : color,
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

                                          // BARRA DE PROGRESSO REAL
                                          if (!isLocked) ...[
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                                bottom: 4.0,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: progress,
                                                  backgroundColor:
                                                      Colors.grey[900],
                                                  color: color,
                                                  minHeight: 6,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              "$completed de $total lições ($progressText)",
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.5,
                                                ),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ] else
                                            Text(
                                              module['description'] ?? '',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.6,
                                                ),
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Seta
                                    if (!isLocked)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8.0,
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
