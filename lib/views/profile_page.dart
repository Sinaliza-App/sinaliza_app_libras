import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';
import 'package:http/http.dart' as http; // Importe o http
import 'dart:convert'; // Importe o convert

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = const FlutterSecureStorage();
  String name = "";
  String email = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final storedName = await _storage.read(key: 'user_name');
    final storedEmail = await _storage.read(key: 'user_email');

    setState(() {
      name = storedName ?? "Usuário";
      email = storedEmail ?? "email@exemplo.com";
    });
  }

  Future<void> _logout() async {
    await _storage.delete(key: 'jwt_token');

    if (!mounted) return;
    // Assim que a tela abre, buscamos os dados mais recentes
    _refreshUserData();
  }

  // --- FUNÇÃO PARA ATUALIZAR OS DADOS (XP) ---
  Future<void> _refreshUserData() async {
    setState(() {
      _isLoading = true;
    });

    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return;

    // ATENÇÃO: Use '10.0.2.2' (Android) ou 'localhost' (Desktop)
    const String apiUrl = 'http://10.0.2.2:3000/users/me';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        // Atualiza o Provider com os dados novos (incluindo o XP novo)
        Provider.of<UserProvider>(context, listen: false).setUser(userData);
      }
    } catch (e) {
      print("Erro ao atualizar perfil: $e");
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

  // PALETA
  static const Color neonGreen = Color(0xFF3DFF8E);
  static const Color neonPurple = Color(0xFF8E5CFF);
  static const Color backgroundDark = Color(0xFF050B18);
  static const Color cardDark = Color(0xFF0A1223);

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;

    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Meu Perfil",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 40),

            // AVATAR COM BORDA NEON
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: cardDark,
                shape: BoxShape.circle,
                border: Border.all(color: neonGreen, width: 3),
                boxShadow: [
                  BoxShadow(color: neonGreen.withOpacity(0.4), blurRadius: 16),
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 60),
            ),

            const SizedBox(height: 22),

            // NOME
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 6),

            // EMAIL
            Text(
              email,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // BOTÃO DE LOGOUT
            GestureDetector(
              onTap: _logout,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: neonPurple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: neonPurple, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: neonPurple.withOpacity(0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
        title: const Text('Meu Perfil'),
        actions: [
          // Botão para atualizar manualmente, se quiser
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshUserData,
          )
        ],
      ),
      body: _isLoading && user == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50),
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      user?.name ?? 'Nome não encontrado',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      user?.email ?? 'E-mail não encontrado',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    
                    const SizedBox(height: 30),

                    // --- CARD DE PONTUAÇÃO (XP) ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Total de XP",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 5),
                          _isLoading 
                            ? const SizedBox(
                                height: 20, 
                                width: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2)
                              )
                            : Text(
                                "${user?.totalScore ?? 0}", // Exibe os pontos atualizados!
                                style: TextStyle(
                                  fontSize: 32, 
                                  fontWeight: FontWeight.bold, 
                                  color: Colors.blue[800]
                                ),
                              ),
                        ],
                      ),
                    ),
                    // ------------------------------

                    const Spacer(),

                    ElevatedButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sair (Logout)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red[700],
                        minimumSize: const Size(double.infinity, 50),
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
    );
  }
}
