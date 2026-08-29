import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sinaliza_app_libras/views/main_tab_screen.dart';
import 'package:sinaliza_app_libras/views/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:sinaliza_app_libras/providers/user_provider.dart';
import 'package:sinaliza_app_libras/services/api_service.dart';
import 'dart:convert';
import 'package:sinaliza_app_libras/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // 1. Espera um pouquinho (2 segundos) para mostrar a logo bonita
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 2. Verifica se a sessão do Supabase foi restaurada
    final session = Supabase.instance.client.auth.currentSession;

    if (!mounted) return;

    // 3. Decisão:
    if (session != null) {
      // Tenta buscar o perfil do usuário para popular o Provider
      try {
        final response = await ApiService.get('$apiBaseUrl/users/me');
        if (response.statusCode == 200) {
          final userData = json.decode(response.body);
          if (mounted) {
            Provider.of<UserProvider>(context, listen: false).setUser(userData as Map<String, dynamic>);
          }
        }
      } catch (e) {
        debugPrint("Erro ao carregar perfil no splash: $e");
      }

      if (!mounted) return;
      // TEM TOKEN -> Vai direto para a Home (Módulos via MainTabScreen)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<dynamic>(builder: (context) => const MainTabScreen()),
      );
    } else {
      // MUDANÇA: Se não tá logado, manda pro Onboarding em vez do Login direto
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<dynamic>(builder: (context) => const OnboardingScreen()), 
        // Lembre de importar o arquivo onboarding_screen.dart no topo
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    // Sua tela bonita com logo e loading neon
    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF02040A), Color.fromARGB(255, 7, 19, 44)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Se tiver uma logo, coloque aqui. Se não, use o ícone/texto:
                const Icon(
                  Icons.waving_hand_outlined,
                  size: 80,
                  color: Color(0xFF00FF9D),
                ),
                const SizedBox(height: 20),
                const Text(
                  "SINALIZA",
                  style: TextStyle(
                    color: Color(0xFF00FF9D),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(color: Color(0xFF00FF9D)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
