import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = const FlutterSecureStorage();
  String name = "";
  String email = "";

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
