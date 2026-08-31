import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:sinaliza_app_libras/theme/app_colors.dart';

class StreakDialog {
  static Future<void> show(BuildContext context, int streak) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.darkBG.withValues(alpha: 0.95), // Fundo quase opaco
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Confetes explosivos
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: ConfettiController(duration: const Duration(seconds: 3))..play(),
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: true,
                  colors: const [
                    AppColors.neonGreen,
                    AppColors.neonBlue,
                    AppColors.neonPurple,
                    AppColors.neonOrange,
                  ],
                  numberOfParticles: 50,
                  gravity: 0.1,
                ),
              ),
              // Conteúdo central
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.deepOrange,
                            size: 150,
                            shadows: [
                              Shadow(
                                color: Colors.orange,
                                blurRadius: 40,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "$streak",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 80,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              shadows: [
                                Shadow(
                                  color: Colors.deepOrange,
                                  blurRadius: 20,
                                )
                              ],
                            ),
                          ),
                          const Text(
                            "DIAS CONSECUTIVOS",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 40),
                          const Text(
                            "Você está pegando fogo! 🔥",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 50),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // Fecha o dialog
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.neonGreen,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 10,
                            ),
                            child: const Text(
                              "CONTINUAR",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
