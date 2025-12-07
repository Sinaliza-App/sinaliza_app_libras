import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:sinaliza_app_libras/constants.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:confetti/confetti.dart';

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
  
  // --- CORES DO DEGRADÊ DE FUNDO (IGUAIS ÀS OUTRAS TELAS) ---
  static const Color bgTop = Color(0xFF02040A);      // Preto (Topo)
  static const Color bgBottom = Color(0xFF020915);   // Azul Escuro (Fundo)
  static const Color cardDark = Color(0xFF0A1223);   // Fundo dos painéis

  // --- CÂMERA ---
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // --- WEBSOCKET ---
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  bool _isStreaming = false;
  DateTime? _lastFrameTime;

  // --- ESTADO DO JOGO ---
  String _detectedGesture = "Nenhum";
  double _detectedConfidence = 0.0;
  bool _isCorrect = false;
  String _targetGesture = "";

  // --- TEMPORIZADOR ---
  DateTime? _firstDetectionTime;
  final int _secondsToHold = 3;
  int _secondsHeld = 0;

  // --- PROGRESSO ---
  bool _isSavingProgress = false;
  final _storage = const FlutterSecureStorage();
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _extractTargetGesture();
    _initializeCamera();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
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
        ResolutionPreset.low, 
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() => _isCameraReady = true);
      _connectToWebSocket();
    } catch (e) {
      debugPrint("Erro ao iniciar câmera: $e");
    }
  }

  void _connectToWebSocket() {
    try {
      // ATENÇÃO: Ajuste o IP conforme necessário
      final wsUrl = Uri.parse(wsBaseUrl);
      _channel = WebSocketChannel.connect(wsUrl);

      _cameraController!.startImageStream((CameraImage image) {
        final now = DateTime.now();
        if (_lastFrameTime != null && 
            now.difference(_lastFrameTime!).inMilliseconds < 100) {
          return; 
        }
        _lastFrameTime = now;

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

        bool isCurrentlyMatching = (confidence > 0.6 && gesture == _targetGesture);

        if (isCurrentlyMatching) {
          _firstDetectionTime ??= DateTime.now();
          final duration = DateTime.now().difference(_firstDetectionTime!);
          _secondsHeld = duration.inSeconds;

          if (_secondsHeld >= _secondsToHold && !_isCorrect) {
            _isCorrect = true; 
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
        debugPrint("Erro WebSocket: $error");
        _isStreaming = false;
      }, onDone: () => _isStreaming = false);
    } catch (e) {
      debugPrint("Erro conexão WS: $e");
    }
  }

  Future<void> _saveProgress() async {
    if (!_isCorrect) return;

    setState(() { _isSavingProgress = true; });
    final token = await _storage.read(key: 'jwt_token');

    if (token == null) {
      if (mounted) setState(() => _isSavingProgress = false);
      return;
    }

    const String apiUrl = 'http://192.168.0.6:3000/progress';
    
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'lesson_id': widget.lesson['id'],
          'score': 10,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      final responseData = json.decode(response.body);

      // --- RESTAURADO: MENSAGENS DE FEEDBACK (SNACKBAR) ---
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
      // -----------------------------------------------------

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
      // AQUI ESTÁ O DEGRADÊ CORRETO (Igual às outras telas)
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop,bgBottom], 
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
                        Text("Faça o sinal para:", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                        Text(_targetGesture, style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Câmera
                    Expanded(
                      child: Container(
                        width: double.infinity, // Força ocupar largura total
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
                        // ClipRRect garante que a imagem não vaze para fora das bordas arredondadas
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _isCameraReady
                              ? LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SizedBox(
                                      width: constraints.maxWidth,
                                      height: constraints.maxHeight,
                                      child: FittedBox(
                                        fit: BoxFit.cover, // <--- O SEGREDO: Preenche tudo cortando excessos
                                        child: SizedBox(
                                          // Invertemos W e H porque a câmera nativa geralmente entrega a imagem 'deitada'
                                          width: _cameraController!.value.previewSize!.height,
                                          height: _cameraController!.value.previewSize!.width,
                                          child: CameraPreview(_cameraController!),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : const Center(
                                  child: CircularProgressIndicator(
                                    color: neonGreen,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    // Feedback (Contador Novo)
                    Container(
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
                            const Text("PARABÉNS!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: neonGreen)),
                          
                          ] else if (_firstDetectionTime != null) ...[
                            Text("MANTENHA O SINAL", style: TextStyle(color: neonOrange.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("${_secondsHeld + 1}", style: const TextStyle(color: neonOrange, fontSize: 46, fontWeight: FontWeight.w900, height: 1)),
                                const SizedBox(width: 4),
                                Text("/ ${_secondsToHold}s", style: TextStyle(color: neonOrange.withValues(alpha: 0.6), fontSize: 20, fontWeight: FontWeight.bold, height: 1.2)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (_secondsHeld + 1) / _secondsToHold,
                                minHeight: 8,
                                backgroundColor: neonOrange.withValues(alpha: 0.2),
                                color: neonOrange,
                              ),
                            ),

                          ] else ...[
                            Text(
                              _detectedGesture != "Nenhum" ? "Detectado: $_detectedGesture" : "Aguardando sinal...",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _detectedGesture != "Nenhum" ? Colors.white : Colors.white.withValues(alpha: 0.4),
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
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isCorrect ? Colors.black : Colors.white.withValues(alpha: 0.5)),
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
                                  )
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
                  colors: const [neonGreen, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
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