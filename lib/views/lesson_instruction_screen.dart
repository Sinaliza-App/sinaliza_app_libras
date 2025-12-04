import 'package:flutter/material.dart';
import 'package:sinaliza_app_libras/views/lesson_detail_screen.dart';

class LessonInstructionScreen extends StatelessWidget {
  final Map<String, dynamic> lesson;

  const LessonInstructionScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    // Cores do Tema
    const Color neonGreen = Color(0xFF00FF9D);
    const Color darkBG = Color(0xFF02040A);
    const Color cardDark = Color(0xFF050C1A);

    final String title = lesson['title'] ?? 'Lição';
    final String description = lesson['description'] ?? 'Sem descrição disponível.';
    
    // Se tiver URL de imagem no banco, usamos. Se não, um placeholder.
    // (No futuro, isso virá do seu backend/assets)
    final String? imageUrl = lesson['example_image_url'];

    return Scaffold(
      backgroundColor: darkBG,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "INSTRUÇÕES DA LIÇÃO",
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 25,fontWeight: FontWeight.w800,
              letterSpacing: 1.5,),
              textAlign: TextAlign.center,
              
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: neonGreen,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            // --- CARTÃO COM A IMAGEM DO SINAL ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: neonGreen.withValues(alpha: 0.05),
                      blurRadius: 30,
                      spreadRadius: 0,
                    )
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Exibe a imagem do sinal se disponível, senão um ícone placeholder
                    Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(1000), // Círculo
                      ),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: 200,
                                height: 200,
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
            
            const SizedBox(height: 40),
            
            // --- BOTÃO DE PRATICAR ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                    // MUDANÇA AQUI:
                    // 1. Usamos push normal (para não fechar esta tela ainda)
                    // 2. Esperamos o resultado da tela da câmera (true se completou)
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LessonDetailScreen(lesson: lesson),
                      ),
                    );

                    // 3. Se voltou com 'true' (sucesso), fechamos esta tela de instrução também
                    if (result == true && context.mounted) {
                      Navigator.pop(context, true); // Passa o 'true' para a lista
                    }
                  },
                style: ElevatedButton.styleFrom(
                  backgroundColor: neonGreen,
                  foregroundColor: darkBG,
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}