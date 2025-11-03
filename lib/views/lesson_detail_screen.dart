import 'package:flutter/material.dart';

class LessonDetailScreen extends StatefulWidget {
  // Vamos receber os dados da lição que foi clicada
  final Map<String, dynamic> lesson;

  const LessonDetailScreen({super.key, required this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  @override
  Widget build(BuildContext context) {
    // Pegamos os dados da lição que veio da tela anterior
    final String lessonTitle = widget.lesson['title'] ?? 'Lição';
    final String lessonDescription = widget.lesson['description'] ?? 'Sem descrição.';

    return Scaffold(
      appBar: AppBar(
        title: Text(lessonTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pratique o sinal para:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              lessonTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              lessonDescription,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Este será o espaço para a câmera
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Área da Câmera (Próximo Passo!)',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Este será o espaço para o feedback
            const Center(
              child: Text(
                'Aguardando seu sinal...',
                style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}