import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool _isLastPage = false;

  // Cores Neon
  static const Color neonGreen = Color(0xFF00FF9D);
  static const Color bgDark = Color(0xFF02040A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Container(
        // Fundo com degradê sutil
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF02040A), Color(0xFF07101F)],
          ),
        ),
        child: Stack(
          children: [
            // CARROSSEL DE PÁGINAS
            PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() => _isLastPage = index == 2);
              },
              children: const [
                OnboardingPage(
                  icon: Icons.back_hand,
                  title: "Aprenda Libras\nna Prática",
                  subtitle: "Use a câmera do seu celular para receber feedback em tempo real sobre seus sinais.",
                ),
                OnboardingPage(
                  icon: Icons.videogame_asset,
                  title: "Gamificação\ne Diversão",
                  subtitle: "Ganhe XP, suba de nível e acompanhe seu progresso enquanto aprende.",
                ),
                OnboardingPage(
                  icon: Icons.rocket_launch,
                  title: "Domine a\nComunicação",
                  subtitle: "Quebre barreiras e conecte-se com o mundo através da Língua de Sinais.",
                ),
              ],
            ),

            // CONTROLES (Rodapé)
            Container(
              alignment: const Alignment(0, 0.85),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Botão Pular
                  TextButton(
                    onPressed: () {
                      _controller.jumpToPage(2);
                    },
                    child: Text(
                      _isLastPage ? "" : "PULAR",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ),

                  // Indicador de Páginas (Bolinhas)
                  SmoothPageIndicator(
                    controller: _controller,
                    count: 3,
                    effect: const ExpandingDotsEffect(
                      activeDotColor: neonGreen,
                      dotColor: Colors.white24,
                      dotHeight: 10,
                      dotWidth: 10,
                    ),
                  ),

                  // Botão Próximo / Começar
                  _isLastPage
                      ? ElevatedButton(
                          onPressed: () {
                            // Vai para o Login e mata a tela de onboarding
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: neonGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text(
                            "COMEÇAR",
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        )
                      : TextButton(
                          onPressed: () {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeIn,
                            );
                          },
                          child: const Text("PRÓXIMO", style: TextStyle(color: Colors.white)),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget auxiliar para cada página
class OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const OnboardingPage({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícone brilhante
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00FF9D).withValues(alpha: 0.1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF9D).withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: 10,
                )
              ],
            ),
            child: Icon(icon, size: 100, color: const Color(0xFF00FF9D)),
          ),
          const SizedBox(height: 60),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}