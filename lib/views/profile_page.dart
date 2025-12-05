import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Imports do seu projeto
import 'package:sinaliza_app_libras/providers/user_provider.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;

  // Cores do Tema
  static const Color neonGreen = Color(0xFF00FF9D);
  static const Color neonRed = Color(0xFFFF4B4B);
  static const Color neonBlue = Color(0xFF00D1FF);
  
  // --- CORES DO DEGRADÊ (IGUAIS À LESSON LIST) ---
  static const Color darkBG = Color(0xFF02040A);   // Topo
  static const Color darkBG2 = Color(0xFF020915);  // Fundo
  
  static const Color cardDark = Color(0xFF07101F); // Fundo dos cards

  @override
  void initState() {
    super.initState();
    _refreshUserData();
  }

  Future<void> _refreshUserData() async {
    setState(() {
      _isLoading = true;
    });

    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // ATENÇÃO: Ajuste o IP conforme necessário (10.0.2.2 ou Radmin)
    const String apiUrl = 'http://26.72.151.39:3000/users/me';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        Provider.of<UserProvider>(context, listen: false).setUser(userData);
      }
    } catch (e) {
      debugPrint("Erro ao atualizar perfil: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    await _storage.delete(key: 'jwt_token');
    
    if (!mounted) return;
    Provider.of<UserProvider>(context, listen: false).clearUser();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;

    return Scaffold(
      // REMOVIDO backgroundColor sólido
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // --- AQUI ESTÁ O DEGRADÊ VERTICAL DE DUAS CORES ---
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [darkBG, darkBG2], // As cores exatas da LessonList
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- HEADER PERSONALIZADO (Para substituir a AppBar) ---
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
                    
                    // Título
                    const Text(
                      "MEU PERFIL",
                      style: TextStyle(
                        color: neonGreen, 
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: 1.5,
                      ),
                    ),
                      //botão refresh
                      Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _refreshUserData,
                      ),
                    ),
                  ],
                ),
              ),
              // --- CONTEÚDO DA TELA ---
                Expanded(
                child: _isLoading && user == null
                    ? const Center(child: CircularProgressIndicator(color: neonGreen))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),

                            // 1. AVATAR COM BORDA NEON
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: cardDark,
                                shape: BoxShape.circle,
                                border: Border.all(color: neonGreen, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: neonGreen.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.person, color: Colors.white, size: 60),
                            ),

                            const SizedBox(height: 22),

                            // 2. NOME E EMAIL
                            // 2. INFORMAÇÕES DO USUÁRIO
                            Text(
                              user?.name ?? 'Usuário',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              user?.email ?? 'email@exemplo.com',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 40),

                            // 3. CARD DE PONTUAÇÃO (XP)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: cardDark,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: neonBlue.withValues(alpha: 0.3),
                                  width: 1.5
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    "EXPERIÊNCIA TOTAL",
                                    style: TextStyle(
                                      color: neonBlue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _isLoading 
                                    ? const SizedBox(
                                        height: 30, width: 30, 
                                        child: CircularProgressIndicator(color: neonBlue)
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            "${user?.totalScore ?? 0}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 48,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            "XP",
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 40),
                            // 4. BOTÃO DE LOGOUT
                            InkWell(
                              onTap: () => _logout(context),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                height: 60,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: neonRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: neonRed.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.logout_rounded, color: neonRed),
                                    SizedBox(width: 12),
                                    Text(
                                      "Sair da Conta",
                                      style: TextStyle(
                                        color: neonRed,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}