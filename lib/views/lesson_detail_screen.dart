import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 1. Importe o Storage
import 'package:http/http.dart' as http; // 2. Importe o HTTP
import 'dart:convert'; // 3. Importe o dart:convert

class LessonDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lesson;
  const LessonDetailScreen({super.key, required this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  CameraController? _cameraController;
  late Future<void> _initializeControllerFuture;
  bool _isCameraInitialized = false;
  bool _isSavingProgress = false; // 4. Variável de loading para o botão

  // 5. Crie a instância do storage
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    CameraDescription selectedCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _cameraController!.initialize();

    _initializeControllerFuture.then((_) {
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
      // TODO: Iniciar o stream de imagens para o backend (Python)
    }).catchError((e) {
      print("Erro ao inicializar a câmera: $e");
    });
  }

  // --- 6. NOVA FUNÇÃO PARA SALVAR O PROGRESSO ---
  Future<void> _saveProgress() async {
    setState(() {
      _isSavingProgress = true;
    });

    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Usuário não autenticado.')),
      );
      setState(() {
        _isSavingProgress = false;
      });
      return;
    }

    // ATENÇÃO: Use '10.0.2.2' (Android) ou 'localhost' (Desktop)
    const String apiUrl = 'http://10.0.2.2:3000/progress';
    final int lessonId = widget.lesson['id'];

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'lesson_id': lessonId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        // --- SUCESSO ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Progresso salvo!')),
        );
        // Volta para a tela de lista (que agora mostrará o "check")
        Navigator.pop(context); 
      } else if (response.statusCode == 409) {
        // --- JÁ SALVO ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Progresso já salvo.')),
        );
        Navigator.pop(context);
      } else {
        // --- OUTROS ERROS ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Erro ao salvar.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: $e')),
      );
    } finally {
      setState(() {
        _isSavingProgress = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String lessonTitle = widget.lesson['title'] ?? 'Lição';

    return Scaffold(
      appBar: AppBar(
        title: Text(lessonTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ... (Textos do título da lição)
            Text(
              'Pratique o sinal para:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              lessonTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // --- ÁREA DA CÂMERA ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isCameraInitialized
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: CameraPreview(_cameraController!),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            
            // --- 7. BOTÃO DE CONCLUIR LIÇÃO ---
            _isSavingProgress
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Concluir Lição'),
                    onPressed: _saveProgress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[50],
                      foregroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}