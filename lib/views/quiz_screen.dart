import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sinaliza_app_libras/constants.dart';
import 'package:sinaliza_app_libras/services/api_service.dart';
import 'package:sinaliza_app_libras/theme/app_colors.dart';
import 'package:sinaliza_app_libras/views/theoretical_quiz_screen.dart';
import 'package:sinaliza_app_libras/views/challenge_sequence_screen.dart';
import 'package:sinaliza_app_libras/widgets/custom_snackbar.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _isLoadingChallenge = false;

  Future<void> _startChallengeMode() async {
    setState(() {
      _isLoadingChallenge = true;
    });

    try {
      final response = await ApiService.get('$apiBaseUrl/dictionary');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        final signs = data.cast<Map<String, dynamic>>();

        if (signs.length < 5) {
          if (mounted) CustomSnackBar.showWarning(context, 'Sinais insuficientes para o desafio.');
          return;
        }

        signs.shuffle(Random());
        final selectedSigns = signs.take(5).toList();

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute<dynamic>(
              builder: (context) => ChallengeSequenceScreen(lessons: selectedSigns),
            ),
          );
        }
      } else {
        if (mounted) CustomSnackBar.showError(context, 'Erro ao carregar desafios.');
      }
    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, 'Erro de conexão.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingChallenge = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBG,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                "ZONA DE TESTES",
                style: TextStyle(
                  color: AppColors.neonGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Escolha seu Desafio",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),

              // Botão Quiz Teórico
              _buildMenuCard(
                title: "Quiz Teórico",
                description: "Teste seus conhecimentos de múltipla escolha com imagens e GIFs.",
                icon: Icons.image_search_rounded,
                color: AppColors.neonBlue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<dynamic>(
                      builder: (context) => const TheoreticalQuizScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Botão Desafio Prático
              _isLoadingChallenge
                  ? const Center(child: CircularProgressIndicator(color: AppColors.neonOrange))
                  : _buildMenuCard(
                      title: "Desafio Prático",
                      description: "Ligue a câmera e mostre o que sabe em sequências de 10 segundos!",
                      icon: Icons.local_fire_department_rounded,
                      color: AppColors.neonOrange,
                      onTap: _startChallengeMode,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 40),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
