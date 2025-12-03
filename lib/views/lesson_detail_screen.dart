import 'dart:async'; 
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:confetti/confetti.dart'; 

class LessonDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lesson;

  const LessonDetailScreen({super.key, required this.lesson});

  @override
  _LessonDetailScreenState createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  // Câmera
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // WebSocket e Jogo
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  bool _isStreaming = false;
  
  // Estado do Jogo
  String _detectedGesture = "Posicione a mão...";
  double _detectedConfidence = 0.0;
  bool _isCorrect = false; 
  String _targetGesture = ""; 

  // Variáveis do Temporizador
  DateTime? _firstDetectionTime; 
  final int _secondsToHold = 3;  
  int _secondsHeld = 0;          

  // Progresso e Efeitos
  bool _isSavingProgress = false;
  final _storage = const FlutterSecureStorage();
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _extractTargetGesture(); 
    _initializeCamera();
    // Confetes duram 2 segundos ao explodir
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  void _extractTargetGesture() {
    final title = widget.lesson['title'].toString();
    if (title.contains("Letra ")) {
      _targetGesture = title.split("Letra ").last.trim();
    } else {
      _targetGesture = title.split(":").last.trim();
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _channel?.sink.close();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _confettiController.dispose();
    super.dispose();
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
    final cameras = await availableCameras();
    CameraDescription selectedCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
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
    _initializeControllerFuture.then((_) {
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
      _connectToWebSocket();
    }).catchError((e) {
      print("Erro ao inicializar a câmera: $e");
    });
  }

  void _connectToWebSocket() {
    try {
      // ATENÇÃO: Use o IP correto (10.0.2.2 ou Radmin)
      final wsUrl = Uri.parse('ws://10.0.2.2:8080');
      _channel = WebSocketChannel.connect(wsUrl);

      _cameraController!.startImageStream((CameraImage image) {
        if (_isStreaming) return; 
        _isStreaming = true;
        final plane = image.planes[0];
        final String imageBase64 = base64Encode(plane.bytes);

        _channel?.sink.add(jsonEncode({
          'image': imageBase64,
          'height': image.height,
          'width': image.width,
          'stride': plane.bytesPerRow,
        }));
      });

      _streamSubscription = _channel?.stream.listen((message) {
        if (!mounted) return;
        final data = json.decode(message);
        
        final String gesture = data['gesto'];
        final double confidence = data['confianca'];

        bool isCurrentlyMatching = false;
        // Validação: Gesto correto E confiança > 60%
        if (confidence > 0.6 && gesture == _targetGesture) {
          isCurrentlyMatching = true;
        }

        if (isCurrentlyMatching) {
          _firstDetectionTime ??= DateTime.now();
          final duration = DateTime.now().difference(_firstDetectionTime!);
          _secondsHeld = duration.inSeconds;

          if (_secondsHeld >= _secondsToHold && !_isCorrect) {
            // VENCEU!
            _isCorrect = true; 
            _confettiController.play(); // Dispara a festa
          }
        } else {
          if (!_isCorrect) { 
             _firstDetectionTime = null;
             _secondsHeld = 0;
          }
        }

        setState(() {
          _detectedGesture = gesture;
          _detectedConfidence = confidence;
        });
        
        _isStreaming = false;
      }, onError: (error) {
        print("Erro no WebSocket: $error");
        _isStreaming = false;
      }, onDone: () {
        print("WebSocket desconectado.");
        _isStreaming = false;
      });
    } catch (e) {
      print("Não foi possível conectar ao WebSocket: $e");
    }
  }

  Future<void> _saveProgress() async {
    if (!_isCorrect) return;

    setState(() { _isSavingProgress = true; });
    final token = await _storage.read(key: 'jwt_token');
    
    if (token == null) { 
      setState(() { _isSavingProgress = false; });
      return; 
    }
    
    const String apiUrl = 'http://10.0.2.2:3000/progress';
    final int lessonId = widget.lesson['id'];
    const int scoreEarned = 10; 

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'lesson_id': lessonId,
          'score': scoreEarned,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      
      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Progresso salvo!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); 
      } else if (response.statusCode == 409) {
        Navigator.pop(context);
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar.')));
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      setState(() { _isSavingProgress = false; });
    }
  }

  // Função auxiliar para cor da barra
  Color _getConfidenceColor(double confidence) {
    if (confidence < 0.4) return Colors.red;
    if (confidence < 0.7) return Colors.orange;
    return Colors.green;
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
      appBar: AppBar(title: Text(lessonTitle)),
      // Stack permite colocar os confetes POR CIMA de tudo
      body: Stack(
        children: [
          // 1. CONTEÚDO PRINCIPAL (EMBAIXO)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Meta
                Column(
                  children: [
                    Text('Faça o sinal para:', style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      _targetGesture, 
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ÁREA DA CÂMERA
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        // Borda muda de cor: Cinza -> Amarelo (contando) -> Verde (venceu)
                        color: _isCorrect ? Colors.green : (_firstDetectionTime != null ? Colors.yellow : Colors.grey),
                        width: _isCorrect ? 4 : (_firstDetectionTime != null ? 3 : 1),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: _isCameraInitialized
                          ? Center(
                              child: AspectRatio(
                                aspectRatio: _cameraController!.value.aspectRatio,
                                child: CameraPreview(_cameraController!),
                              ),
                            )
                          : const Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // --- FEEDBACK E BARRA DE CONFIANÇA (FEATURE-015) ---
                Column(
                  children: [
                    // Texto de Feedback
                    if (_isCorrect)
                      const Text("PARABÉNS! 🎉", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green))
                    else if (_firstDetectionTime != null)
                      Text(
                        "Segure... ${_secondsHeld + 1}/$_secondsToHold",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                      )
                    else if (_detectedGesture != "Nenhum")
                      Text("Detectado: $_detectedGesture", style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold))
                    else
                      const Text("Posicione a mão...", style: TextStyle(fontSize: 18, color: Colors.grey)),
                    
                    const SizedBox(height: 10),

                    // BARRA DE PROGRESSO (Confiança)
                    if (!_isCorrect) // Só mostra se ainda não venceu
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _detectedConfidence, // Valor de 0.0 a 1.0
                              minHeight: 15,
                              backgroundColor: Colors.grey[300],
                              color: _getConfidenceColor(_detectedConfidence), // Muda de cor
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "${(_detectedConfidence * 100).toInt()}% de certeza",
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // BOTÃO DE CONCLUIR
                _isSavingProgress
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        icon: Icon(_isCorrect ? Icons.check_circle : Icons.lock),
                        label: Text(_isCorrect ? 'Concluir Lição (+10 XP)' : 'Acerte o sinal para liberar'),
                        onPressed: _isCorrect ? _saveProgress : null, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
              ],
            ),
          ),

          // 2. WIDGET DE CONFETE (CORRIGIDO E EXPANDIDO)
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox.expand( // Garante que ocupe espaço para cair
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive, 
                shouldLoop: false, 
                colors: const [
                  Colors.green, Colors.blue, Colors.pink, 
                  Colors.orange, Colors.purple, Colors.red
                ], 
                numberOfParticles: 50, // Mais confetes
                gravity: 0.3, 
                minBlastForce: 10,
                maxBlastForce: 30,
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
        ],
      ),
    );
  }
}
