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

  // Cores do Tema (Baseado no seu Login)
  static const Color neonGreen = Color(0xFF00FF9D);
  static const Color neonPurple = Color(0xFF8E5CFF);
  static const Color darkBackground = Color(0xFF02040A);
  static const Color cardDark = Color(0xFF050C1A);

  @override
  void initState() {
    super.initState();
    _refreshUserData();
  }

  // Função para buscar dados atualizados (incluindo XP)
  Future<void> _refreshUserData() async {
    setState(() {
      _isLoading = true;
    });

    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return;

    // ATENÇÃO: Use o IP correto (10.0.2.2 ou Radmin)
    const String apiUrl = 'http://26.72.151.39:3000/users/me';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        // Atualiza o Provider com os dados novos
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

  Future<void> _logout() async {
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
    // Lê os dados do Provider
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Meu Perfil",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: neonGreen),
            onPressed: _refreshUserData,
          )
        ],
      ),
      body: _isLoading && user == null
          ? const Center(child: CircularProgressIndicator(color: neonGreen))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(height: 20),

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
                            color: neonGreen.withValues(alpha: 0.4), // Correção Linter
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 60),
                    ),

                    const SizedBox(height: 22),

                    // 2. NOME E EMAIL
                    Text(
                      user?.name ?? 'Nome não encontrado',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user?.email ?? 'E-mail não encontrado',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7), // Correção Linter
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // 3. CARD DE PONTUAÇÃO (XP)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withValues(alpha: 0.1),
                            blurRadius: 10,
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Total de XP",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                                )
                              : Text(
                                  "${user?.totalScore ?? 0}",
                                  style: const TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // 4. BOTÃO DE LOGOUT
                    GestureDetector(
                      onTap: _logout,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: neonPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: neonPurple, width: 1.6),
                          boxShadow: [
                            BoxShadow(
                              color: neonPurple.withValues(alpha: 0.1),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.logout, color: neonPurple),
                            SizedBox(width: 10),
                            Text(
                              "Sair (Logout)",
                              style: TextStyle(
                                color: neonPurple,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
    );
  }
}