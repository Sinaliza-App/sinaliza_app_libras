import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class LessonDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lesson;

  const LessonDetailScreen({super.key, required this.lesson});

  @override
  _LessonDetailScreenState createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint("Erro ao iniciar câmera: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color neonGreen = Color(0xFF00FF9D);
    const Color darkBG = Color(0xFF02040A);
    const Color cardDark = Color(0xFF050C1A);

    final String lessonTitle = widget.lesson['title'] ?? 'Lição';
    final String description = widget.lesson['description'] ?? '';

    return Scaffold(
      backgroundColor: darkBG,
      appBar: AppBar(
        backgroundColor: darkBG,
        elevation: 0,
        iconTheme: const IconThemeData(color: neonGreen),
        title: Text(
          lessonTitle,
          style: const TextStyle(
            color: neonGreen,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ---------- TÍTULO DA LIÇÃO ----------
            Text(
              "Pratique o sinal para:",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lessonTitle,
              style: const TextStyle(
                color: neonGreen,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // ---------- CAIXA COM CAMERA ----------
            Container(
              height: 380,
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: neonGreen.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _isCameraReady
                    ? CameraPreview(_cameraController!)
                    : Container(
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                          color: neonGreen,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 22),

            // ---------- STATUS ----------
            Text(
              "Aguardando seu sinal...",
              style: TextStyle(
                color: neonGreen.withOpacity(0.9),
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 12),

            // ---------- DESCRIÇÃO DA LIÇÃO ----------
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
