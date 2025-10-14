import 'package:flutter/material.dart';
import 'package:sinaliza_app_libras/helpers/database_helper.dart';
import 'dart:developer' as developer;

class LessonListScreen extends StatefulWidget {
  const LessonListScreen({super.key});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  final dbHelper = DatabaseHelper();
  late Future<List<Map<String, dynamic>>> _lessons;

  @override
  void initState() {
    super.initState();
    // Inicia a busca pelas lições assim que a tela é criada.
    _lessons = dbHelper.getLessons();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lições de Libras')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _lessons, // O Future que o builder vai "ouvir"
        builder: (context, snapshot) {
          // 1. Enquanto os dados estão carregando, mostre um spinner.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. Se ocorreu um erro na busca.
          if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar as lições: ${snapshot.error}'),
            );
          }
          // 3. Se os dados foram carregados com sucesso, mas a lista está vazia.
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma lição encontrada.'));
          }

          // 4. Se tudo deu certo, construa a lista.
          final lessons = snapshot.data!;
          return ListView.builder(
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              return ListTile(
                leading: const Icon(Icons.sign_language),
                title: Text(lesson['title']),
                subtitle: Text(lesson['description']),
                onTap: () {
               
                  developer.log(
                    'Clicou na lição: ${lesson['title']}',
                    name: 'LessonListScreen',
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
