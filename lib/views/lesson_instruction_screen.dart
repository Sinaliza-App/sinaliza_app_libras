import 'package:flutter/material.dart';
import 'package:sinaliza_app_libras/views/lesson_detail_screen.dart';
import 'package:sinaliza_app_libras/widgets/animations/fade_in_slide.dart';
import 'package:sinaliza_app_libras/theme/app_colors.dart';

class LessonInstructionScreen extends StatelessWidget {
  final Map<String, dynamic> lesson;

  const LessonInstructionScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final String title = (lesson['title'] as String?) ?? 'Lição';
    final String description = (lesson['description'] as String?) ?? 'Sem descrição disponível.';
    
    // Prioriza o gif, depois a imagem de exemplo, depois a thumbnail
    final String? imageUrl = (lesson['gif_url'] as String?) ?? (lesson['example_image_url'] as String?) ?? (lesson['thumbnail_url'] as String?);
    final bool isNetwork = imageUrl != null && imageUrl.startsWith('http');

    return Scaffold(
      backgroundColor: AppColors.darkBG,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.darkBG, AppColors.darkBG2],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeInSlide(
                  duration: const Duration(milliseconds: 400),
                  child: const Text(
                    "INSTRUÇÕES DA LIÇÃO",
                    style: TextStyle(
                      color: Colors.white60, 
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 15),
                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.neonGreen,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // --- CARTÃO COM A IMAGEM DO SINAL ---
                Expanded(
                  child: FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonGreen.withValues(alpha: 0.05),
                            blurRadius: 30,
                            spreadRadius: 0,
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 240,
                            width: 240,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(24), // Quadrado arredondado
                            ),
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: isNetwork 
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover, // Para o gif preencher o círculo
                                          errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.broken_image, size: 80, color: Colors.white54),
                                        )
                                      : Image.asset( 
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.broken_image, size: 80, color: Colors.white54),
                                        ),
                                  )
                                : const Icon(Icons.front_hand, size: 80, color: Colors.white54),
                          ),
                          const SizedBox(height: 32),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Text(
                              description,
                              style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // --- BOTÃO DE PRATICAR ---
                FadeInSlide(
                  duration: const Duration(milliseconds: 700),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                          // MUDANÇA AQUI:
                          // 1. Usamos push normal (para não fechar esta tela ainda)
                          // 2. Esperamos o resultado da tela da câmera (true se completou)
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute<dynamic>(
                              builder: (context) => LessonDetailScreen(lesson: lesson),
                            ),
                          );
      
                          // 3. Se voltou com 'true' (sucesso), fechamos esta tela de instrução também
                          if (result == true && context.mounted) {
                            Navigator.pop(context, true); // Passa o 'true' para a lista
                          }
                        },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonGreen,
                        foregroundColor: AppColors.darkBG,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text(
                        "PRATICAR AGORA",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}