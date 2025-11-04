import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // 1. Importe o pacote da câmera

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

  @override
  void initState() {
    super.initState();
    // Inicia a câmera assim que a tela for criada
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // 1. Obter a lista de câmeras disponíveis
    final cameras = await availableCameras();
    
    // 2. Selecionar a câmera frontal (selfie)
    CameraDescription selectedCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first, // Se não achar a frontal, usa a primeira que tiver
    );

    // 3. Criar e inicializar o controlador
    _cameraController = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _cameraController!.initialize();

    // 4. Atualizar a UI quando a câmera estiver pronta
    _initializeControllerFuture.then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCameraInitialized = true;
      });
      
      // TODO: Iniciar o stream de imagens para o backend (Python)
      // _cameraController!.startImageStream((image) {
      //   // Enviar 'image' para a API de Visão Computacional
      // });
    }).catchError((e) {
      print("Erro ao inicializar a câmera: $e");
    });
  }

  @override
  void dispose() {
    // 5. Descartar o controlador quando a tela for fechada
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
            // ... (o texto "Pratique o sinal para:" etc. continua igual)
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
                        // 6. Exibe a prévia da câmera
                        child: CameraPreview(_cameraController!),
                      )
                    : const Center(
                        // 7. Mostra um loading enquanto a câmera inicializa
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            
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