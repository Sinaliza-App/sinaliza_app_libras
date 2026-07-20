import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'package:sinaliza_app_libras/services/api_service.dart';
import 'package:sinaliza_app_libras/constants.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart'; // Para o compute()

// --- FUNÇÃO ISOLADA (FORA DA CLASSE) PARA NÃO TRAVAR A UI ---
String _processFrameInIsolate(Uint8List bytes) {
  return base64Encode(bytes);
}

class LessonDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lesson;

  const LessonDetailScreen({super.key, required this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  // --- PALETA DE CORES NEON ---
  static const Color neonGreen = Color(0xFF00FF9D);
  static const Color neonOrange = Color(0xFFFF9900);

  // --- CORES DO DEGRADÊ DE FUNDO ---
  static const Color bgTop = Color(0xFF02040A);
  static const Color bgBottom = Color.fromARGB(255, 7, 19, 44);
  static const Color cardDark = Color(0xFF0A1223);

  // --- CÂMERA E INFERÊNCIA WEBSOCKET ---
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessingFrame = false; // Trava para não afogar o servidor
  DateTime? _lastFrameTime;
  WebSocketChannel? _channel;
  bool _isConnected = false;

  // --- ESTADO DO JOGO ---
  String _detectedGesture = "Nenhum";
  double _detectedConfidence = 0.0;
  bool _isCorrect = false;
  String _targetGesture = "";
  bool _isMovement = false; // Flag para UI adaptativa

  // --- TEMPORIZADOR ---
  DateTime? _firstDetectionTime;
  int _secondsToHold = 3;
  int _secondsHeld = 0;

  // --- PROGRESSO E EFEITOS ---
  bool _isSavingProgress = false;
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _extractTargetGesture();
    _initializeCamera();
    _connectWebSocket();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsBaseUrl));
      _isConnected = true;
      
      _channel!.stream.listen(
        (message) {
          if (!mounted) return;
          try {
            final data = jsonDecode(message);
            final String gesture = data['prediction'] ?? "Nenhum";
            final double confidence = (data['confidence'] ?? 0.0).toDouble();

            _handleDetectionResult(gesture, confidence);
          } catch (e) {
            debugPrint("Erro ao decodificar resposta do WS: $e");
          } finally {
            _isProcessingFrame = false;
          }
        },
        onError: (error) {
          debugPrint("Erro no WebSocket: $error");
          _isConnected = false;
          _isProcessingFrame = false;
        },
        onDone: () {
          debugPrint("WebSocket desconectado");
          _isConnected = false;
          _isProcessingFrame = false;
        },
      );
    } catch (e) {
      debugPrint("Falha ao conectar WebSocket: $e");
      _isConnected = false;
    }
  }

  void _extractTargetGesture() {
    final title = widget.lesson['title'].toString();
    if (title.contains("Letra ")) {
      _targetGesture = title.split("Letra ").last.trim();
    } else {
      _targetGesture = title.split(":").last.trim();
    }
    
    // Regra Inteligente: Se for movimento, o usuário ganha em 1s (pequeno delay).
    // Se for estático (Alfabeto), ele precisa segurar a pose (3s).
    final lessonType = (widget.lesson['type'] ?? 'estatico').toString().toLowerCase();
    _isMovement = lessonType == 'movimento';
    _secondsToHold = _isMovement ? 1 : 3;
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _channel?.sink.close();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() => _isCameraReady = true);
      _startVisionStream(); // Inicia o envio via WebSocket
    } catch (e) {
      debugPrint("Erro ao iniciar câmera: $e");
    }
  }

 // --- NOVA LÓGICA WEBSOCKET COM ISOLATE ---
 void _startVisionStream() {
    _cameraController!.startImageStream((CameraImage image) async {
      // Ignora se não estiver conectado, se já estiver processando ou se já acertou
      if (!_isConnected || _isProcessingFrame || _isCorrect) return;

      final now = DateTime.now();
      // Otimizamos para até 10 frames por segundo de processamento para maior fluidez
      if (_lastFrameTime != null && now.difference(_lastFrameTime!).inMilliseconds < 100) {
        return;
      }
      
      _lastFrameTime = now;
      _isProcessingFrame = true; // Trava o envio até a resposta voltar

      try {
        final plane = image.planes[0];
        
        // --- O SEGREDO DO FPS ALTO ---
        // Usamos o compute() para jogar a conversão pesada Base64 para outra Thread!
        final String imageBase64 = await compute(_processFrameInIsolate, plane.bytes);

        // Dispara direto no Socket (muito mais rápido que HTTP)
        _channel!.sink.add(jsonEncode({
          'image': imageBase64,
          'width': image.width,
          'height': image.height,
          'stride': plane.bytesPerRow,
          'model_type': (widget.lesson['type'] ?? 'estatico').toString().toLowerCase() == 'movimento' ? 'movimento' : 'alfabeto'
        }));
      } catch (e) {
        debugPrint("Erro no processamento do frame: $e");
        _isProcessingFrame = false;
      }
    });
  }

  // --- LÓGICA DE VALIDAÇÃO ISOLADA ---
 void _handleDetectionResult(String gesture, double confidence) async {
    bool isCurrentlyMatching = (confidence > 0.6 && gesture == _targetGesture);

    if (isCurrentlyMatching) {
      if (!_isCorrect) {
        if (_firstDetectionTime == null) {
          _firstDetectionTime = DateTime.now();
          _secondsHeld = 0;
        } else {
          _secondsHeld = DateTime.now().difference(_firstDetectionTime!).inSeconds;
        }

        // Se bateu a meta (ex: 3 segundos ou instantâneo)
        if (_secondsHeld >= _secondsToHold) {
          _isCorrect = true;
          _onSuccess();
        }
      }
    } else {
      if (!_isCorrect) {
        // IA piscou ou o usuário mexeu a mão: Zera o cronômetro!
        _firstDetectionTime = null;
        _secondsHeld = 0;
      }
    }

    // Atualiza a tela com o que a IA está enxergando agora
    setState(() {
      _detectedGesture = gesture;
      _detectedConfidence = confidence;
    });
  }

  void _onSuccess() async {
    setState(() {
      _isCorrect = true;
    });

    _confettiController.play();

    if (await Vibration.hasVibrator()) {
      if (_isMovement) {
        // Vibração dupla para movimento (impacto imediato)
        Vibration.vibrate(pattern: [0, 150, 100, 150]);
      } else {
        // Vibração simples para estático
        Vibration.vibrate(duration: 500);
      }
    }
    try {
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
    } catch (e) {
      debugPrint("Erro ao tocar som: $e");
    }
  }

  Future<void> _saveProgress() async {
    if (!_isCorrect) return;

    setState(() {
      _isSavingProgress = true;
    });

    const String apiUrl = '$apiBaseUrl/progress';

    try {
      final response = await ApiService.post(
            apiUrl,
            body: json.encode({'lesson_id': widget.lesson['id'], 'score': 10}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Progresso salvo! +10 XP'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      } else if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você já concluiu esta lição.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar progresso.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isSavingProgress = false);
    }
  }

  Color _getStatusColor() {
    if (_isCorrect) return neonGreen;
    if (_firstDetectionTime != null) return neonOrange;
    return Colors.white.withValues(alpha: 0.2);
  }

  @override
  Widget build(BuildContext context) {
    final String lessonTitle = widget.lesson['title'] ?? 'Lição';
    final Color statusColor = _getStatusColor();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              lessonTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: neonGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),

                    // Meta
                    Column(
                      children: [
                        Text(
                          _secondsToHold == 0 ? "Faça o movimento para:" : "Faça o sinal para:",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _targetGesture,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(color: neonGreen.withValues(alpha: 0.6), blurRadius: 15),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Câmera
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: statusColor,
                            width: _isCorrect || _firstDetectionTime != null ? 4 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: _isCorrect ? 0.5 : 0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _isCameraReady
                              ? LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SizedBox(
                                      width: constraints.maxWidth,
                                      height: constraints.maxHeight,
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: _cameraController!.value.previewSize!.height,
                                          height: _cameraController!.value.previewSize!.width,
                                          child: CameraPreview(_cameraController!),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : const Center(
                                  child: CircularProgressIndicator(color: neonGreen),
                                ),
                        ),
                      ),
                    ),

                    // Feedback (Contador)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        children: [
                          if (_isCorrect) ...[
                            const Icon(Icons.celebration, color: neonGreen, size: 32),
                            const SizedBox(height: 8),
                            const Text(
                              "PARABÉNS!",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: neonGreen,
                              ),
                            ),
                          ] else if (_firstDetectionTime != null) ...[
                            Text(
                              _isMovement ? "ANALISANDO MOVIMENTO" : "MANTENHA O SINAL",
                              style: TextStyle(
                                color: neonOrange.withValues(alpha: 0.8),
                                fontSize: _isMovement ? 14 : 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (!_isMovement) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${_secondsHeld + 1}",
                                    style: const TextStyle(
                                      color: neonOrange,
                                      fontSize: 46,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "/ $_secondsToHold s",
                                    style: TextStyle(
                                      color: neonOrange.withValues(alpha: 0.8),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: CircularProgressIndicator(color: neonOrange),
                              ),
                            ],
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (_secondsHeld + 1) / (_secondsToHold == 0 ? 1 : _secondsToHold),
                                minHeight: 8,
                                backgroundColor: neonOrange.withValues(alpha: 0.2),
                                color: neonOrange,
                              ),
                            ),
                          ] else ...[
                            Text(
                              _detectedGesture != "Nenhum"
                                  ? "Detectado: $_detectedGesture"
                                  : (_secondsToHold == 0 ? "Faça o movimento para a câmera..." : "Posicione sua mão na câmera..."),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _detectedGesture != "Nenhum"
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _detectedConfidence,
                                minHeight: 8,
                                backgroundColor: Colors.grey[800],
                                color: _detectedConfidence > 0.6 ? neonGreen : neonOrange,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Botão
                    _isSavingProgress
                        ? const Center(child: CircularProgressIndicator(color: neonGreen))
                        : SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              icon: Icon(
                                _isCorrect ? Icons.check_circle : Icons.lock,
                                color: _isCorrect ? Colors.black : Colors.white.withValues(alpha: 0.5),
                              ),
                              label: Text(
                                _isCorrect ? 'CONCLUIR LIÇÃO (+10 XP)' : 'Acerte o sinal para liberar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isCorrect ? Colors.black : Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                              onPressed: _isCorrect ? _saveProgress : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: neonGreen,
                                disabledBackgroundColor: cardDark,
                                elevation: _isCorrect ? 4 : 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: _isCorrect ? Colors.transparent : Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    neonGreen,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                  ],
                  numberOfParticles: 40,
                  gravity: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}