import 'dart:async';
import 'dart:convert';
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
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  // Cores
  static const Color neonGreen = Color(0xFF00FF9D);
  static const Color darkBG = Color(0xFF02040A);
  static const Color cardDark = Color(0xFF050C1A);

  // Câmera
  CameraController? _cameraController;
  late Future<void> _initializeControllerFuture;
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
      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _initializeControllerFuture = _cameraController!.initialize();

      await _initializeControllerFuture;

      if (!mounted) return;
      if (!mounted) return;
      setState(() {
        _isCameraReady = true;
      });
      _connectToWebSocket();
    } catch (e) {
      debugPrint("Erro ao iniciar câmera: $e");
    }
  }

  void _connectToWebSocket() {
    try {
      // ATENÇÃO: Ajuste o IP conforme necessário (10.0.2.2 ou Radmin)
      final wsUrl = Uri.parse('ws://26.72.151.39:8080');
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
        if (confidence > 0.6 && gesture == _targetGesture) {
          isCurrentlyMatching = true;
        }

        if (isCurrentlyMatching) {
          _firstDetectionTime ??= DateTime.now();
          final duration = DateTime.now().difference(_firstDetectionTime!);
          _secondsHeld = duration.inSeconds;

          if (_secondsHeld >= _secondsToHold && !_isCorrect) {
            _isCorrect = true; // VENCEU!
            _confettiController.play();
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
        debugPrint("Erro no WebSocket: $error");
        _isStreaming = false;
      }, onDone: () {
        debugPrint("WebSocket desconectado.");
        _isStreaming = false;
      });
    } catch (e) {
      debugPrint("Não foi possível conectar ao WebSocket: $e");
    }
  }

  Future<void> _saveProgress() async {
    if (!_isCorrect) return;

    setState(() {
      _isSavingProgress = true;
    });
    final token = await _storage.read(key: 'jwt_token');

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Usuário não autenticado.')),
      );
      setState(() {
        _isSavingProgress = false;
      });
      return;
    }

    const String apiUrl = 'http://26.72.151.39:3000/progress';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você já completou esta lição.')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProgress = false;
        });
      }
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence < 0.4) return Colors.red;
    if (confidence < 0.7) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Pratique o sinal para:",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _targetGesture,
                  style: const TextStyle(
                    color: neonGreen,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isCorrect
                            ? Colors.green
                            : (_firstDetectionTime != null
                                ? Colors.yellow
                                : Colors.transparent),
                        width: _isCorrect
                            ? 4
                            : (_firstDetectionTime != null ? 3 : 0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: neonGreen.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _isCameraReady
                          ? Center(
                              child: AspectRatio(
                                aspectRatio:
                                    _cameraController!.value.aspectRatio,
                                child: CameraPreview(_cameraController!),
                              ),
                            )
                          : Container(
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                color: neonGreen,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  children: [
                    if (_isCorrect)
                      const Text(
                        "PARABÉNS! 🎉",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      )
                    else if (_firstDetectionTime != null)
                      Text(
                        "Segure... ${_secondsHeld + 1}/$_secondsToHold",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      )
                    else if (_detectedGesture != "Nenhum")
                      Text(
                        "Detectado: $_detectedGesture",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Text(
                        "Aguardando seu sinal...",
                        style: TextStyle(
                          color: neonGreen.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (!_isCorrect)
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _detectedConfidence,
                              minHeight: 10,
                              backgroundColor: Colors.grey[800],
                              color: _getConfidenceColor(_detectedConfidence),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "${(_detectedConfidence * 100).toInt()}% de certeza",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _isSavingProgress
                    ? const Center(
                        child: CircularProgressIndicator(color: neonGreen),
                      )
                    : ElevatedButton.icon(
                        icon: Icon(
                          _isCorrect ? Icons.check_circle : Icons.lock,
                        ),
                        label: Text(
                          _isCorrect
                              ? 'Concluir Lição (+10 XP)'
                              : 'Acerte o sinal para liberar',
                        ),
                        onPressed: _isCorrect ? _saveProgress : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[800],
                          disabledForegroundColor: Colors.grey[500],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox.expand(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.red
                ],
                numberOfParticles: 50,
                gravity: 0.3,
                minBlastForce: 10,
                maxBlastForce: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}