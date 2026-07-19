import 'package:flutter/material.dart';

import 'package:sinaliza_app_libras/services/api_service.dart';
import 'dart:convert';
import 'package:sinaliza_app_libras/constants.dart'; // Seu arquivo de IP

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  List<dynamic> _ranking = [];
  bool _isLoading = true;

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
    _fetchRanking();
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
                              // Ajusta o índice porque pulamos os 3 primeiros
                              final user = _ranking[index + 3];
                              final int position = index + 4;

                              return Container(
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
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.blueGrey,
                                      backgroundImage: user['profile_picture'] != null && user['profile_picture'].toString().isNotEmpty
                                          ? MemoryImage(base64Decode(user['profile_picture']))
                                          : null,
                                      child: (user['profile_picture'] == null || user['profile_picture'].toString().isEmpty)
                                          ? Text(
                                              user['name'].toString().substring(0, 1).toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            )
                                          : null,
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

                                    // XP
                                    Text(
                                      "${user['total_score']} XP",
                                      style: const TextStyle(color: neonGreen, fontWeight: FontWeight.bold),
                                    ),
                                  ],
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
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Coroa para o 1º lugar
          if (isFirst) 
             const Icon(Icons.emoji_events, color: neonGold, size: 40),
          
          const SizedBox(height: 8),

          // Avatar no topo do pilar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 1)
              ],
            ),
            child: CircleAvatar(
              radius: isFirst ? 35 : 25,
              backgroundColor: cardDark,
              backgroundImage: user['profile_picture'] != null && user['profile_picture'].toString().isNotEmpty
                  ? MemoryImage(base64Decode(user['profile_picture']))
                  : null,
              child: (user['profile_picture'] == null || user['profile_picture'].toString().isEmpty)
                  ? Text(
                      user['name'].toString().substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: isFirst ? 24 : 18,
                      ),
                    )
                  : null,
            ),
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

          // O Pilar (Barra Colorida)
          Container(
            width: double.infinity,
            height: height, // Altura variável
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2), // Cor transparente
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                top: BorderSide(color: color, width: 2),
                left: BorderSide(color: color.withValues(alpha: 0.3)),
                right: BorderSide(color: color.withValues(alpha: 0.3)),
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
            child: Column(
              children: [
                const SizedBox(height: 10),
                Text(
                  "$position",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: isFirst ? 40 : 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}