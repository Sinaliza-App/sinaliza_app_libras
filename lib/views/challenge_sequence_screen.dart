import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'package:sinaliza_app_libras/services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sinaliza_app_libras/theme/app_colors.dart';
import 'package:sinaliza_app_libras/constants.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart'; // Para o compute()
import 'package:provider/provider.dart';
import 'package:sinaliza_app_libras/providers/user_provider.dart';

import 'package:sinaliza_app_libras/widgets/custom_snackbar.dart';
import 'package:sinaliza_app_libras/widgets/streak_dialog.dart';

// --- FUNÇÃO ISOLADA (FORA DA CLASSE) PARA NÃO TRAVAR A UI ---
String _processFrameInIsolate(Uint8List bytes) {
  return base64Encode(bytes);
}

class ChallengeSequenceScreen extends StatefulWidget {
  final List<Map<String, dynamic>> lessons;

  const ChallengeSequenceScreen({super.key, required this.lessons});

  @override
  State<ChallengeSequenceScreen> createState() => _ChallengeSequenceScreenState();
}

class _ChallengeSequenceScreenState extends State<ChallengeSequenceScreen> {
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
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- DESAFIO SEQUENCIAL ---
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _isChallengeFinished = false;
  int _challengeTimeLeft = 10;
  Timer? _challengeTimer;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _extractTargetGesture();
    _initializeCamera();
    _connectWebSocket();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsBaseUrl));
      _isConnected = true;
      
      _channel!.stream.listen(
        (dynamic message) {
          if (!mounted) return;
          try {
            final Map<String, dynamic> data = jsonDecode(message as String) as Map<String, dynamic>;
            final String gesture = (data['prediction'] as String?) ?? "Nenhum";
            final double confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;

            _handleDetectionResult(gesture, confidence);
          } catch (e) {
            debugPrint("Erro ao decodificar resposta do WS: $e");
          } finally {
            _isProcessingFrame = false;
          }
        },
        onError: (dynamic error) {
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
    final lesson = widget.lessons[_currentIndex];
    final title = lesson['title'].toString();
    if (title.contains("Letra ")) {
      _targetGesture = title.split("Letra ").last.trim();
    } else {
      _targetGesture = title.split(":").last.trim();
    }
    
    // Regra Inteligente: Se for movimento, o usuário ganha instantaneamente (0s).
    // Se for estático (Alfabeto), ele precisa segurar a pose (3s).
    final lessonType = (lesson['type'] ?? 'estatico').toString().toLowerCase();
    _isMovement = lessonType == 'movimento' || lessonType == 'dynamic';
    _secondsToHold = _isMovement ? 0 : 3;
    _challengeTimeLeft = 10;
    _isCorrect = false;
    _firstDetectionTime = null;
    _secondsHeld = 0;
    _detectedGesture = "Nenhum";
    _detectedConfidence = 0.0;
  }

  @override
  void dispose() {
    _challengeTimer?.cancel();
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
      _startChallengeTimer();
    } catch (e) {
      debugPrint("Erro ao iniciar câmera: $e");
    }
  }

  void _startChallengeTimer() {
    _challengeTimer?.cancel();
    _challengeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isCorrect || _isTransitioning || _isChallengeFinished) {
        return; // Não cancelamos o timer, só ignoramos o tick se estiver transicionando
      }
      setState(() {
        if (_challengeTimeLeft > 0) {
          _challengeTimeLeft--;
        } else {
          _handleChallengeFailure();
        }
      });
    });
  }

  Future<void> _handleChallengeFailure() async {
    setState(() {
      _isTransitioning = true;
    });
    
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 500, 200, 500]);
    }
    
    // Registra erro silenciosamente no banco
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.rpc<void>('increment_quiz_error', params: {
          'p_user_id': userId,
          'p_sign_id': widget.lessons[_currentIndex]['id']
        });
      }
    } catch (e) {
      debugPrint("Erro ao registrar falha no desafio: $e");
    }

    if (!mounted) return;
    CustomSnackBar.showError(context, "Tempo Esgotado!");
    await Future<void>.delayed(const Duration(seconds: 2));
    
    _nextChallenge();
  }

  void _nextChallenge() {
    if (!mounted) return;
    setState(() {
      if (_currentIndex < widget.lessons.length - 1) {
        _currentIndex++;
        _extractTargetGesture();
        _isTransitioning = false;
      } else {
        _isChallengeFinished = true;
        _challengeTimer?.cancel();
        _saveProgress(); // Salva pontuação final
      }
    });
  }

 // --- NOVA LÓGICA WEBSOCKET COM ISOLATE ---
 void _startVisionStream() {
    _cameraController!.startImageStream((CameraImage image) async {
      if (!_isConnected || _isProcessingFrame || _isCorrect || _isTransitioning || _isChallengeFinished) return;

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
          'model_type': (widget.lessons[_currentIndex]['type'] ?? 'estatico').toString().toLowerCase() == 'movimento' ? 'movimento' : 'alfabeto'
        }));
      } catch (e) {
        debugPrint("Erro no processamento do frame: $e");
        _isProcessingFrame = false;
      }
    });
  }

  String _normalizeGesture(String gesture) {
    // Troca espaços, barras, hifens por underline e converte pra minúsculo (Padrão do Modelo Python)
    return gesture.toLowerCase()
        .replaceAll(RegExp(r'[áàâã]'), 'a')
        .replaceAll(RegExp(r'[éèê]'), 'e')
        .replaceAll(RegExp(r'[íìî]'), 'i')
        .replaceAll(RegExp(r'[óòôõ]'), 'o')
        .replaceAll(RegExp(r'[úùû]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[\s/|-]+'), '_')
        .trim();
  }

  // --- LÓGICA DE VALIDAÇÃO ISOLADA ---
 void _handleDetectionResult(String gesture, double confidence) async {
    if (_isTransitioning || _isChallengeFinished) return;
    // Para movimentos confiamos 100% no backend (já que ele filtra a confianca), para estáticos > 0.6
    final String normalizedDetected = _normalizeGesture(gesture);
    final String normalizedTarget = _normalizeGesture(_targetGesture);

    final bool isCurrentlyMatching = ((_isMovement || confidence > 0.6) && 
                                normalizedDetected == normalizedTarget && 
                                normalizedDetected != "nenhum");

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
      _isTransitioning = true;
      _correctCount++;
    });

    _confettiController.play();

    if (await Vibration.hasVibrator()) {
      if (_isMovement) {
        Vibration.vibrate(pattern: [0, 150, 100, 150]);
      } else {
        Vibration.vibrate(duration: 500);
      }
    }
    try {
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
    } catch (e) {
      debugPrint("Erro ao tocar som: $e");
    }
    
    await Future<void>.delayed(const Duration(seconds: 2));
    _nextChallenge();
  }

  // --- NOVA FUNÇÃO: REPORTAR (DENÚNCIA) ---
  Future<String?> _showReportDialog(BuildContext context) async {
    final TextEditingController descCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text("Reportar Problema", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: descCtrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          cursorColor: AppColors.neonRed,
          decoration: const InputDecoration(
            hintText: "O que há de errado nesta lição?",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.neonRed)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, descCtrl.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonRed, foregroundColor: Colors.white),
            child: const Text("ENVIAR"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProgress() async {
    final int totalXp = _correctCount * 20;
    
    // Mostra tela de fim de jogo
    if (!mounted) return;
    showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Desafio Concluído!', style: TextStyle(color: AppColors.neonGreen, fontWeight: FontWeight.bold, fontSize: 24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, color: AppColors.neonGreen, size: 80),
            const SizedBox(height: 16),
            Text(
              'Você acertou $_correctCount de ${widget.lessons.length}!',
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '+$totalXp XP',
              style: const TextStyle(color: AppColors.neonGreen, fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // fecha modal
                Navigator.pop(context, true); // fecha tela
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('VOLTAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );

    if (totalXp == 0) return; // Nao salva no banco se não acertou nada

    final String apiUrl = '$apiBaseUrl/progress';
    try {
      // Nota: Podemos estar salvando no progresso da última lição, ou idealmente ter uma tabela separada.
      // Aqui salvaremos em nome da última lição só para creditar o XP.
      final response = await ApiService.post(
            apiUrl,
            body: json.encode({'lesson_id': widget.lessons.last['id'], 'score': totalXp}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      final responseData = json.decode(response.body);
      final currentStreak = Provider.of<UserProvider>(context, listen: false).user?.streakCount ?? 0;

      if (responseData['streak_count'] != null) {
        final int newStreak = responseData['streak_count'] as int;
        Provider.of<UserProvider>(context, listen: false).updateStreak(newStreak);
        
        if (newStreak > currentStreak) {
          await StreakDialog.show(context, newStreak);
        }
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        Provider.of<UserProvider>(context, listen: false).addScore(totalXp);
      }
    } catch (e) {
      debugPrint("Erro ao salvar progresso do desafio: $e");
    }
  }

  Color _getStatusColor() {
    if (_isCorrect) return AppColors.neonGreen;
    if (_firstDetectionTime != null) return AppColors.neonOrange;
    return Colors.white.withValues(alpha: 0.2);
  }

  @override
  Widget build(BuildContext context) {
    if (_isChallengeFinished) {
      return const Scaffold(
        backgroundColor: AppColors.darkBG,
        body: Center(child: CircularProgressIndicator(color: AppColors.neonGreen)),
      );
    }

    final lesson = widget.lessons[_currentIndex];
    final String lessonTitle = "Sinal ${_currentIndex + 1} de ${widget.lessons.length}";
    final Color statusColor = _getStatusColor();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.darkBG, AppColors.darkBG2],
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
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              _challengeTimer?.cancel();
                              Navigator.pop(context);
                            },
                          ),
                          Expanded(
                            child: Text(
                              lessonTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.neonOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.flag_outlined, color: AppColors.neonRed),
                            tooltip: 'Reportar problema',
                            onPressed: () async {
                              final desc = await _showReportDialog(context);
                              if (desc != null && desc.trim().isNotEmpty) {
                                try {
                                  final userId = Supabase.instance.client.auth.currentUser?.id;
                                  if (userId != null) {
                                    await Supabase.instance.client.rpc<void>('increment_quiz_error', params: {
                                      'p_user_id': userId,
                                      'p_sign_id': lesson['id'],
                                    });
                                  }
                                  await Supabase.instance.client.from('reports').insert({
                                    'user_id': userId,
                                    'target_type': 'lesson',
                                    'target_id': lesson['id'],
                                    'description': desc,
                                  });
                                  if (!context.mounted) return;
                                  CustomSnackBar.showSuccess(context, 'Report enviado aos administradores!');
                                } catch (e) {
                                  if (!context.mounted) return;
                                  CustomSnackBar.showError(context, 'Erro ao enviar report.');
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // Meta
                    Column(
                      children: [
                        if (!_isCorrect && !_isTransitioning) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            decoration: BoxDecoration(
                              color: _challengeTimeLeft <= 3 ? AppColors.neonRed.withValues(alpha: 0.2) : AppColors.neonOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: _challengeTimeLeft <= 3 ? AppColors.neonRed : AppColors.neonOrange),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined, color: _challengeTimeLeft <= 3 ? AppColors.neonRed : AppColors.neonOrange, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  "00:${_challengeTimeLeft.toString().padLeft(2, '0')}",
                                  style: TextStyle(
                                    color: _challengeTimeLeft <= 3 ? AppColors.neonRed : AppColors.neonOrange,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
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
                              Shadow(color: AppColors.neonOrange.withValues(alpha: 0.6), blurRadius: 15),
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
                                  child: CircularProgressIndicator(color: AppColors.neonGreen),
                                ),
                        ),
                      ),
                    ),

                    // Feedback (Contador)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        children: [
                          if (_isCorrect) ...[
                            const Icon(Icons.stars, color: AppColors.neonGreen, size: 60),
                            const SizedBox(height: 8),
                            const Text(
                              "PARABÉNS!",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.neonGreen,
                              ),
                            ),
                          ] else if (_firstDetectionTime != null) ...[
                            Text(
                              _isMovement ? "ANALISANDO MOVIMENTO" : "MANTENHA O SINAL",
                              style: TextStyle(
                                color: AppColors.neonOrange.withValues(alpha: 0.8),
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
                                      color: AppColors.neonOrange,
                                      fontSize: 46,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "/ $_secondsToHold s",
                                    style: TextStyle(
                                      color: AppColors.neonOrange.withValues(alpha: 0.8),
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
                                child: CircularProgressIndicator(color: AppColors.neonOrange),
                              ),
                            ],
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (_secondsHeld + 1) / (_secondsToHold == 0 ? 1 : _secondsToHold),
                                minHeight: 8,
                                backgroundColor: AppColors.neonOrange.withValues(alpha: 0.2),
                                color: AppColors.neonOrange,
                              ),
                            ),
                          ] else ...[
                            if (!_isMovement) ...[
                              Text(
                                _detectedGesture != "Nenhum"
                                    ? "Detectado: $_detectedGesture"
                                    : "Posicione sua mão na câmera...",
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
                                  color: _detectedConfidence > 0.6 ? AppColors.neonGreen : AppColors.neonOrange,
                                ),
                              ),
                            ] else ...[
                              Text(
                                "Faça o movimento para a câmera...",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Botão (removido, o salto é automático, ou mostra infos extras aqui)
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
                    AppColors.neonGreen,
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