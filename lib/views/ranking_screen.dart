import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'package:sinaliza_app_libras/services/api_service.dart';
import 'dart:convert';
import 'package:sinaliza_app_libras/constants.dart'; // Seu arquivo de IP

// Removido controle global obsoleto

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> with TickerProviderStateMixin {
  List<dynamic> _ranking = [];
  bool _isLoading = true;

  late AnimationController _entranceController;
  late Animation<double> _podium3Animation;
  late Animation<double> _podium2Animation;
  late Animation<double> _podium1Animation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Cores Neon
  static const Color neonGreen = Color(0xFF00FF9D);
  static const Color neonGold = Color(0xFFFFD700);
  static const Color neonSilver = Color(0xFFE0E0E0); // Prata mais clara
  static const Color neonBronze = Color(0xFFCD7F32);
  static const Color cardDark = Color(0xFF0A1223);
  static const Color bgDark = Color(0xFF02040A);
  static const Color bgDark2 = Color.fromARGB(255, 7, 19, 44);

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _podium3Animation = CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic));
    _podium2Animation = CurvedAnimation(parent: _entranceController, curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic));
    _podium1Animation = CurvedAnimation(parent: _entranceController, curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic));

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    // Roda a animação toda vez que a tela for aberta
    _entranceController.forward(from: 0.0);

    _fetchRanking();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Uint8List? _safeDecodeBase64(String? base64StrNullable) {
    if (base64StrNullable == null || base64StrNullable.isEmpty) return null;
    try {
      String base64Str = base64StrNullable;
      if (base64Str.contains(',')) {
        base64Str = base64Str.split(',').last;
      }
      // Remove espaços em branco e quebras de linha
      base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');
      // Conserta o padding se não for múltiplo de 4
      while (base64Str.length % 4 != 0) {
        base64Str += '=';
      }
      return base64Decode(base64Str);
    } catch (e) {
      return null;
    }
  }

  // --- LOGICA DAS LIGAS ---
  Color _getLeagueColor(int score) {
    if (score >= 1100) return Colors.cyanAccent; // Diamante
    if (score >= 600) return neonGold; // Ouro
    if (score >= 300) return neonSilver; // Prata
    return neonBronze; // Bronze
  }

  IconData _getLeagueIcon(int score) {
    if (score >= 1100) return Icons.diamond_rounded;
    if (score >= 600) return Icons.emoji_events;
    if (score >= 300) return Icons.military_tech;
    return Icons.shield;
  }

  Future<void> _fetchRanking() async {
    // Ajuste o IP conforme necessário
    final url = '$apiBaseUrl/ranking'; 

    try {
      final response = await ApiService.get(url);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _ranking = json.decode(response.body);
            // Pré-decodifica as imagens aqui para não travar a UI a cada frame
            for (var user in _ranking) {
              if (user is Map) {
                user['decoded_image'] = _safeDecodeBase64(user['profile_picture']?.toString());
              }
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Erro ranking: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Faz o degradê ir até o topo
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          "RANKING GLOBAL",
          style: TextStyle(color: neonGreen, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgDark, bgDark2],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: neonGreen))
            : _ranking.isEmpty
                ? const Center(child: Text("Nenhum aluno pontuou ainda.", style: TextStyle(color: Colors.white)))
                : Column(
                    children: [
                      const SizedBox(height: 100), // Espaço para a AppBar

                      // --- PÓDIO (TOP 3) ---
                      if (_ranking.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            height: 400, // Altura da área do pódio
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 2º LUGAR (Esquerda)
                                if (_ranking.length > 1)
                                  _buildPodiumPlace(
                                    user: _ranking[1],
                                    position: 2,
                                    color: neonSilver,
                                    height: 140,
                                  ),
                                
                                // 1º LUGAR (Centro - Maior)
                                _buildPodiumPlace(
                                  user: _ranking[0],
                                  position: 1,
                                  color: neonGold,
                                  height: 180,
                                  isFirst: true,
                                ),

                                // 3º LUGAR (Direita)
                                if (_ranking.length > 2)
                                  _buildPodiumPlace(
                                    user: _ranking[2],
                                    position: 3,
                                    color: neonBronze,
                                    height: 110,
                                  ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // --- LISTA DO RESTO (4º em diante) ---
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: cardDark,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 40),
                            itemCount: _ranking.length > 3 ? _ranking.length - 3 : 0,
                            itemBuilder: (context, index) {
                              final user = _ranking[index + 3];
                              final position = index + 4;
                              
                              return AnimatedBuilder(
                                animation: _entranceController,
                                builder: (context, child) {
                                  double start = 0.5 + (index * 0.05);
                                  double end = start + 0.3;
                                  
                                  double itemValue = 1.0;
                                  if (!_entranceController.isCompleted) {
                                    if (_entranceController.value <= start) {
                                      itemValue = 0.0;
                                    } else if (_entranceController.value >= end) {
                                      itemValue = 1.0;
                                    } else {
                                      itemValue = (_entranceController.value - start) / (end - start);
                                    }
                                    itemValue = Curves.easeOutCubic.transform(itemValue.clamp(0.0, 1.0));
                                  }

                                  return Transform.translate(
                                    offset: Offset(0, 50 * (1 - itemValue)),
                                    child: Opacity(
                                      opacity: itemValue,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                  ),
                                  child: Row(
                                    children: [
                                      // Posição
                                      Text(
                                        "$position",
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      
                                      // Avatar Pequeno
                                      Builder(
                                        builder: (context) {
                                          final Uint8List? imageBytes = user['decoded_image'] as Uint8List?;
                                          final Widget fallbackText = Text(
                                            user['name'].toString().substring(0, 1).toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          );

                                          return CircleAvatar(
                                            radius: 20,
                                            backgroundColor: Colors.blueGrey,
                                            backgroundImage: imageBytes != null ? MemoryImage(imageBytes) : null,
                                            child: imageBytes == null ? fallbackText : null,
                                          );
                                        }
                                      ),
                                      const SizedBox(width: 12),

                                      // Nome
                                      Expanded(
                                        child: Text(
                                          user['name'],
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),

                                      // XP e Liga
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "${user['total_score']} XP",
                                            style: TextStyle(
                                              color: _getLeagueColor(user['total_score']),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                _getLeagueIcon(user['total_score']),
                                                color: _getLeagueColor(user['total_score']),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                user['total_score'] >= 1100 ? "Diamante" : 
                                                user['total_score'] >= 600 ? "Ouro" :
                                                user['total_score'] >= 300 ? "Prata" : "Bronze",
                                                style: TextStyle(
                                                  color: _getLeagueColor(user['total_score']).withValues(alpha: 0.8),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  // Widget Auxiliar para desenhar cada pilar do pódio
  Widget _buildPodiumPlace({
    required dynamic user,
    required int position,
    required Color color,
    required double height,
    bool isFirst = false,
  }) {
    Animation<double> podiumAnim = position == 3 ? _podium3Animation : (position == 2 ? _podium2Animation : _podium1Animation);

    return Expanded(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entranceController, _pulseController]),
        builder: (context, child) {
          return _buildPodiumContent(
            user, 
            position, 
            color, 
            height, 
            isFirst, 
            podiumAnim.value, 
            _pulseAnimation.value
          );
        },
      ),
    );
  }

  // Conteúdo isolado para reaproveitar com ou sem animação
  Widget _buildPodiumContent(dynamic user, int position, Color color, double height, bool isFirst, double entranceValue, double pulseValue) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Elementos do topo do pilar ganham fadeIn
        Opacity(
          opacity: entranceValue.clamp(0.0, 1.0),
          child: Column(
            children: [
              // Coroa para o 1º lugar
              if (isFirst) 
                 const Icon(Icons.emoji_events, color: neonGold, size: 40),
              
              const SizedBox(height: 8),

              // Avatar no topo do pilar
              Builder(
                builder: (context) {
                  final Uint8List? imageBytes = user['decoded_image'] as Uint8List?;
                  final Widget fallbackText = Text(
                    user['name'].toString().substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: isFirst ? 24 : 18,
                    ),
                  );

                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5), 
                          blurRadius: (10 * pulseValue).clamp(0.0, double.infinity), // Respiração contínua
                          spreadRadius: (2 * pulseValue).clamp(0.0, double.infinity)
                        )
                      ],
                    ),
                    child: CircleAvatar(
                      radius: isFirst ? 35 : 25,
                      backgroundColor: cardDark,
                      backgroundImage: imageBytes != null ? MemoryImage(imageBytes) : null,
                      child: imageBytes == null ? fallbackText : null,
                    ),
                  );
                }
              ),
              const SizedBox(height: 8),
              
              // Nome do Usuário
              Text(
                user['name'].split(" ")[0], // Pega só o primeiro nome
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
              
              // Pontuação
              Text(
                "${user['total_score']} XP",
                style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),

        // O Pilar (Barra Colorida) cresce do zero
        Container(
          width: double.infinity,
          height: (height * entranceValue).clamp(0.0, double.infinity), // Cresce de forma suave e não pode ser negativo
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2), // Cor transparente
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.5),
              width: 1.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.0),
              ]
            )
          ),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Opacity(
                  opacity: entranceValue.clamp(0.0, 1.0),
                  child: Text(
                    position == 1 ? "🥇" : (position == 2 ? "🥈" : "🥉"),
                    style: TextStyle(
                      fontSize: isFirst ? 45 : 30,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}