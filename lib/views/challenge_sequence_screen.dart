import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'package:sinaliza_app_libras/services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sinaliza_app_libras/theme/app_colors.dart';
import 'package:sinaliza_app_libras/constants.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:provider/provider.dart';
import 'package:sinaliza_app_libras/providers/user_provider.dart';

import 'package:sinaliza_app_libras/widgets/custom_snackbar.dart';
import 'package:sinaliza_app_libras/widgets/streak_dialog.dart';
import 'package:sinaliza_app_libras/services/vision_extractor_service.dart';
import 'package:sinaliza_app_libras/services/libras_inference_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/widgets/animations/fade_in_slide.dart';

class ChallengeSequenceScreen extends StatefulWidget {
  final List<Map<String, dynamic>> lessons;
  final int? moduleId;

  const ChallengeSequenceScreen({
    super.key, 
    required this.lessons,
    this.moduleId,
  });

  @override
  State<ChallengeSequenceScreen> createState() =>
      _ChallengeSequenceScreenState();
}

class _ChallengeSequenceScreenState extends State<ChallengeSequenceScreen> {
  // --- IA OFFLINE ---
  final VisionExtractorService _visionExtractor = VisionExtractorService();
  final LibrasInferenceService _inferenceService = LibrasInferenceService();
  final List<List<double>> _frameBuffer = [];

  // --- CÂMERA ---
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessingFrame = false; // Trava para processamento
  DateTime? _lastFrameTime;
  bool _isConnected = false; // Reflete se a IA local está pronta

  // --- ESTADO DO JOGO ---
  String _detectedGesture = "Nenhum";
  double _detectedConfidence = 0.0;
  bool _isCorrect = false;
  String _targetGesture = "";
  bool _isMovement = false; // Flag para UI adaptativa
  List<dynamic> _lastLandmarks = []; // Matriz de 30x258

  // --- TEMPORIZADOR ---
  DateTime? _firstDetectionTime;
  DateTime? _lastMatchTime;
  int _secondsToHold = 2;
  int _secondsHeld = 0;

  // --- PROGRESSO E EFEITOS ---
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- DESAFIO SEQUENCIAL ---
  bool _showIntro = true;
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
    _initializeLocalAI();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
  }

  void _startChallenge() {
    setState(() {
      _showIntro = false;
    });
    _initializeCamera();
  }

  Future<void> _initializeLocalAI() async {
    try {
      if (!_visionExtractor.isInitialized) {
        await _visionExtractor.initialize();
      }
      if (!_inferenceService.isInitialized) {
        await _inferenceService.initialize();
      }
      if (mounted) {
        setState(() {
          _isConnected = true; // IA pronta
        });
      }
    } catch (e) {
      debugPrint("Falha ao inicializar IA Local: $e");
      if (mounted) {
        CustomSnackBar.showError(context, "Falha ao iniciar IA offline: $e");
      }
    }
  }

  void _extractTargetGesture() {
    final lesson = widget.lessons[_currentIndex];
    if (lesson['sign_name'] != null && lesson['sign_name'].toString().trim().isNotEmpty) {
      _targetGesture = lesson['sign_name'].toString().trim();
    } else {
      final title = lesson['title'].toString();
      if (title.contains("Letra ")) {
        _targetGesture = title.split("Letra ").last.trim();
      } else {
        _targetGesture = title.split(":").last.trim();
      }
    }

    // Regra Inteligente: Se for movimento, o usuário ganha instantaneamente (0s).
    // Se for estático (Alfabeto), ele precisa segurar a pose (2s).
    final lessonType = (lesson['type'] ?? 'estatico').toString().toLowerCase();
    _isMovement = lessonType == 'movimento' || lessonType == 'dynamic';
    _secondsToHold = _isMovement ? 0 : 2;
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
        await Supabase.instance.client.rpc<void>(
          'increment_quiz_error',
          params: {
            'p_user_id': userId,
            'p_sign_id': widget.lessons[_currentIndex]['id'],
          },
        );
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
        _frameBuffer.clear(); // Limpa buffer da lição anterior
        _extractTargetGesture();
        _isTransitioning = false;
      } else {
        _isChallengeFinished = true;
        _challengeTimer?.cancel();
        _saveProgress(); // Salva pontuação final
      }
    });
  }

  Future<void> _reportError() async {
    if (_lastLandmarks.isEmpty || _lastLandmarks.length != 30) {
      CustomSnackBar.showError(
        context,
        "Nenhum dado capturado ainda. Aguarde.",
      );
      return;
    }
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final payload = {
        "user_id": userId,
        "sign_name": _targetGesture,
        "source": "mobile_feedback",
        "reporter_role": "student",
        "raw_landmarks": _lastLandmarks,
      };

      final response = await ApiService.post(
        '$apiBaseUrl/coleta/amostra',
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (userId != null) {
          final res = await Supabase.instance.client
              .from('profiles')
              .select('total_score')
              .eq('id', userId)
              .single();
          final currentScore = res['total_score'] as int? ?? 0;
          await Supabase.instance.client
              .from('profiles')
              .update({'total_score': currentScore + 10})
              .eq('id', userId);
        }
        if (mounted) {
          Provider.of<UserProvider>(context, listen: false).addScore(10);
          CustomSnackBar.showSuccess(
            context,
            "Amostra enviada para revisão do professor! +10 XP",
          );
        }
      } else {
        if (mounted) {
          CustomSnackBar.showError(
            context,
            "Erro ao enviar amostra: ${response.statusCode}",
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(
          context,
          "Erro de rede ao reportar incorreção.",
        );
      }
    }
  }

  // --- NOVA LÓGICA 100% OFFLINE (SEM TRAVAMENTO DE PREVIEW) ---
  void _startVisionStream() {
    _cameraController!.startImageStream((CameraImage image) {
      if (!_isConnected ||
          _isProcessingFrame ||
          _isCorrect ||
          _isTransitioning ||
          _isChallengeFinished) {
        return;
      }

      final now = DateTime.now();
      // Throttle: 60ms para dinâmico (~16 FPS) e 100ms para estático (~10 FPS)
      final int throttleMs = _isMovement ? 60 : 100;
      if (_lastFrameTime != null && now.difference(_lastFrameTime!).inMilliseconds < throttleMs) {
        return;
      }

      _lastFrameTime = now;
      _isProcessingFrame = true;

      _processFrameAsync(image);
    });
  }

  Future<void> _processFrameAsync(CameraImage image) async {
    try {
      // 1. Extrai o frame
      final int sensorOrientation = _cameraController!.description.sensorOrientation;
      final lensDirection = _cameraController!.description.lensDirection;
      final features = await _visionExtractor.processImage(
        image, 
        sensorOrientation,
        isMovement: _isMovement,
        lensDirection: lensDirection,
      );

      // Noise gate: se as features estão zeradas, nenhuma mão foi detectada
      if (features.every((v) => v == 0.0)) {
        final now = DateTime.now();
        if (_lastMatchTime == null || now.difference(_lastMatchTime!).inMilliseconds > 450) {
          if (_detectedGesture != "Nenhum") {
            _handleDetectionResult("Nenhum", 0.0);
          }
        }
        return;
      }

      if (mounted) {
        // 2. Alimenta buffer
        _frameBuffer.add(features);
        if (_frameBuffer.length > 30) {
          _frameBuffer.removeAt(0);
        }

        _lastLandmarks = List.from(_frameBuffer);

        // 3. Inferência local no ONNX
        if (!_isMovement) {
          // Alfabeto (MLP): Usa apenas o frame atual
          final result = await _inferenceService.predictAlphabet(features);
          debugPrint("📝 Challenge Alfabeto: $result");
          
          final String gesture = (result['prediction'] as String?) ?? "Nenhum";
          final double confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
          
          _handleDetectionResult(gesture, confidence);
        } else {
          // Gestos (LSTM): Requer o buffer completo de 30 frames
          if (_frameBuffer.length == 30) {
            final result = await _inferenceService.predict(_frameBuffer);
            debugPrint("🏃‍♂️ Challenge Movimento: $result");
            
            final String gesture = (result['prediction'] as String?) ?? "Nenhum";
            final double confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
            
            _handleDetectionResult(gesture, confidence);
          }
        }
      }
    } catch (e) {
      debugPrint("Erro no processamento local do frame: $e");
    } finally {
      final int coolDownMs = _isMovement ? 20 : 60;
      await Future<void>.delayed(Duration(milliseconds: coolDownMs));
      if (mounted) _isProcessingFrame = false;
    }
  }

  String _normalizeGesture(String gesture) {
    String g = gesture.toLowerCase().trim();
    // Normalização específica para Ç / C_CEDILHA
    g = g.replaceAll('c_cedilha', 'c_cedilha')
         .replaceAll('c-cedilha', 'c_cedilha')
         .replaceAll('c cedilha', 'c_cedilha')
         .replaceAll('ç', 'c_cedilha');

    // Remove pontuações (ex: "Tudo bem?" -> "tudo bem")
    g = g.replaceAll(RegExp(r'[?!.,;:()\[\]{}]'), '');

    return g
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[\s/|-]+'), '_')
        .trim();
  }

  // --- LÓGICA DE VALIDAÇÃO ISOLADA ---
  void _handleDetectionResult(String gesture, double confidence) async {
    if (_isTransitioning || _isChallengeFinished) return;
    final String normalizedDetected = _normalizeGesture(gesture);
    final String normalizedTarget = _normalizeGesture(_targetGesture);

    debugPrint("🎯 Challenge Validando: '$normalizedDetected' vs '$normalizedTarget' (Confiança: $confidence)");

    final double minConfidence = _isMovement ? 0.45 : 0.50;
    final bool isCurrentlyMatching = (confidence >= minConfidence &&
        normalizedDetected == normalizedTarget &&
        normalizedDetected != "nenhum");

    final now = DateTime.now();
    if (isCurrentlyMatching) {
      _lastMatchTime = now;
      if (!_isCorrect) {
        if (_firstDetectionTime == null) {
          _firstDetectionTime = now;
          _secondsHeld = 0;
        } else {
          _secondsHeld = DateTime.now()
              .difference(_firstDetectionTime!)
              .inSeconds;
        }

        // Se bateu a meta (ex: 2 segundos ou instantâneo)
        if (_secondsHeld >= _secondsToHold) {
          _isCorrect = true;
          _onSuccess();
        }
      }
    } else {
      if (!_isCorrect) {
        // Tolerância de 450ms antes de zerar o progresso
        // Evita que 1 frame com ruído ou piscar de câmera zere o usuário!
        if (_lastMatchTime == null || now.difference(_lastMatchTime!).inMilliseconds > 450) {
          _firstDetectionTime = null;
          _secondsHeld = 0;
        }
      }
    }

    // Atualiza a tela com o que a IA está enxergando agora
    setState(() {
      _detectedConfidence = confidence;
      if (confidence >= (_isMovement ? 0.40 : 0.45)) {
        _detectedGesture = gesture;
      } else {
        _detectedGesture = "Aguardando...";
      }
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



  Future<void> _saveProgress() async {
    final int totalXp = _correctCount * 20;

    if (!mounted) return;

    // Calcula o percentual e define a identidade visual do resultado
    final double percentage = widget.lessons.isEmpty
        ? 0
        : _correctCount / widget.lessons.length;
    final String emoji;
    final String title;
    final Color accentColor;
    final List<Color> confettiColors;

    if (percentage == 1.0) {
      emoji = '🏆';
      title = 'PERFEITO!';
      accentColor = AppColors.neonGold;
      confettiColors = const [AppColors.neonGold, Colors.white, Colors.yellow];
    } else if (percentage >= 0.6) {
      emoji = '🔥';
      title = 'MUITO BOM!';
      accentColor = AppColors.neonGreen;
      confettiColors = const [
        AppColors.neonGreen,
        AppColors.neonBlue,
        AppColors.neonOrange,
      ];
    } else if (percentage >= 0.3) {
      emoji = '💪';
      title = 'CONTINUE PRATICANDO!';
      accentColor = AppColors.neonOrange;
      confettiColors = const [
        AppColors.neonOrange,
        AppColors.neonRed,
        Colors.white,
      ];
    } else {
      emoji = '📚';
      title = 'ESTUDE MAIS!';
      accentColor = AppColors.neonRed;
      confettiColors = const [AppColors.neonRed, Colors.white, Colors.grey];
    }

    // Mostra tela de fim de jogo com estilo moderno
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.darkBG.withValues(alpha: 0.95),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        final confettiController = ConfettiController(
          duration: const Duration(seconds: 3),
        )..play();

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: confettiController,
                  blastDirection: pi / 2,
                  maxBlastForce: 5,
                  minBlastForce: 2,
                  emissionFrequency: 0.05,
                  numberOfParticles: 50,
                  gravity: 0.1,
                  colors: confettiColors,
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 72)),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.1),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Sua Pontuação',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_correctCount / ${widget.lessons.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(color: Colors.white24, height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.flash_on_rounded,
                                  color: AppColors.neonOrange,
                                  size: 28,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '+$totalXp XP',
                                  style: const TextStyle(
                                    color: AppColors.neonOrange,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () {
                            confettiController.dispose();
                            Navigator.pop(context); // fecha modal
                            Navigator.pop(context, true); // fecha tela
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.black,
                            elevation: 8,
                            shadowColor: accentColor.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'VOLTAR AO MENU',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (totalXp == 0) return; // Nao salva no banco se não acertou nada

    final userId = Supabase.instance.client.auth.currentUser?.id;

    // 1. Salva localmente que o Boss do módulo foi concluído com sucesso
    if (userId != null && widget.moduleId != null) {
      try {
        const storage = FlutterSecureStorage();
        await storage.write(key: 'boss_completed_${widget.moduleId}_$userId', value: 'true');
      } catch (e) {
        debugPrint("Aviso ao salvar status de conclusão do boss: $e");
      }
    }

    // 2. Atualiza pontuação e streak no Backend PostgreSQL (conta para Ranking e Perfil)
    final int currentStreak = mounted 
        ? (Provider.of<UserProvider>(context, listen: false).user?.streakCount ?? 0) 
        : 0;

    try {
      final challengeRes = await ApiService.post(
        '$apiBaseUrl/challenge/progress',
        body: json.encode({
          'module_id': widget.moduleId,
          'score': totalXp,
        }),
      ).timeout(const Duration(seconds: 10));

      if (mounted && (challengeRes.statusCode == 200 || challengeRes.statusCode == 201)) {
        final responseData = json.decode(challengeRes.body);

        if (responseData['streak_count'] != null) {
          final int newStreak = responseData['streak_count'] as int;
          Provider.of<UserProvider>(context, listen: false).updateStreak(newStreak);
          if (newStreak > currentStreak) {
            await StreakDialog.show(context, newStreak);
          }
        }
      } else {
        // Fallback para rota /progress convencional se o backend antigo responder
        await ApiService.post(
          '$apiBaseUrl/progress',
          body: json.encode({
            'lesson_id': widget.lessons.last['id'],
            'score': totalXp,
          }),
        ).timeout(const Duration(seconds: 8));
      }
    } catch (e) {
      debugPrint("Aviso ao registrar desafio no backend: $e");
    }

    // 3. Atualiza pontuação direta no Supabase (profiles.total_score)
    if (userId != null) {
      try {
        final res = await Supabase.instance.client
            .from('profiles')
            .select('total_score')
            .eq('id', userId)
            .maybeSingle();
        if (res != null) {
          final currentScore = (res['total_score'] as num?)?.toInt() ?? 0;
          await Supabase.instance.client
              .from('profiles')
              .update({'total_score': currentScore + totalXp})
              .eq('id', userId);
        }
      } catch (e) {
        debugPrint("Aviso ao atualizar profile no Supabase: $e");
      }
    }

    // 4. Atualiza estado em memória no Provider imediatamente
    if (mounted) {
      Provider.of<UserProvider>(context, listen: false).addScore(totalXp);
    }
  }

  Color _getStatusColor() {
    if (_isCorrect) return AppColors.neonGreen;
    if (_firstDetectionTime != null) return AppColors.neonOrange;
    return Colors.white.withValues(alpha: 0.2);
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return _buildIntroScreen();
    }

    if (_isChallengeFinished) {
      return const Scaffold(
        backgroundColor: AppColors.darkBG,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.neonGreen),
        ),
      );
    }

    final String lessonTitle =
        "Sinal ${_currentIndex + 1} de ${widget.lessons.length}";
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
                            icon: const Icon(
                              Icons.flag_outlined,
                              color: AppColors.neonRed,
                            ),
                            tooltip: 'Reportar problema na IA',
                            onPressed: _reportError,
                          ),
                        ],
                      ),
                    ),

                    // Meta
                    Column(
                      children: [
                        if (!_isCorrect && !_isTransitioning) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _challengeTimeLeft <= 3
                                  ? AppColors.neonRed.withValues(alpha: 0.2)
                                  : AppColors.neonOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: _challengeTimeLeft <= 3
                                    ? AppColors.neonRed
                                    : AppColors.neonOrange,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  color: _challengeTimeLeft <= 3
                                      ? AppColors.neonRed
                                      : AppColors.neonOrange,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "00:${_challengeTimeLeft.toString().padLeft(2, '0')}",
                                  style: TextStyle(
                                    color: _challengeTimeLeft <= 3
                                        ? AppColors.neonRed
                                        : AppColors.neonOrange,
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
                          _secondsToHold == 0
                              ? "Faça o movimento para:"
                              : "Faça o sinal para:",
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
                              Shadow(
                                color: AppColors.neonOrange.withValues(
                                  alpha: 0.6,
                                ),
                                blurRadius: 15,
                              ),
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
                            width: _isCorrect || _firstDetectionTime != null
                                ? 4
                                : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(
                                alpha: _isCorrect ? 0.5 : 0.2,
                              ),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _isCameraReady
                                  ? LayoutBuilder(
                                      builder: (context, constraints) {
                                        return SizedBox(
                                          width: constraints.maxWidth,
                                          height: constraints.maxHeight,
                                          child: FittedBox(
                                            fit: BoxFit.cover,
                                            child: SizedBox(
                                              width: _cameraController!
                                                  .value
                                                  .previewSize!
                                                  .height,
                                              height: _cameraController!
                                                  .value
                                                  .previewSize!
                                                  .width,
                                              child: CameraPreview(
                                                _cameraController!,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.neonGreen,
                                      ),
                                    ),
                              if (!_isConnected)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  child: const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(
                                          color: AppColors.neonGreen,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          "Carregando Inteligência Artificial...",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          "Preparando modelos neurais offline",
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Feedback (Contador)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (_isCorrect) ...[
                            const Icon(
                              Icons.stars,
                              color: AppColors.neonGreen,
                              size: 60,
                            ),
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
                              _isMovement
                                  ? "ANALISANDO MOVIMENTO"
                                  : "MANTENHA O SINAL",
                              style: TextStyle(
                                color: AppColors.neonOrange.withValues(
                                  alpha: 0.8,
                                ),
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
                                      color: AppColors.neonOrange.withValues(
                                        alpha: 0.8,
                                      ),
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
                                child: CircularProgressIndicator(
                                  color: AppColors.neonOrange,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value:
                                    (_secondsHeld + 1) /
                                    (_secondsToHold == 0 ? 1 : _secondsToHold),
                                minHeight: 8,
                                backgroundColor: AppColors.neonOrange
                                    .withValues(alpha: 0.2),
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
                                  color: _detectedConfidence > 0.6
                                      ? AppColors.neonGreen
                                      : AppColors.neonOrange,
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

  Widget _buildIntroScreen() {
    return Scaffold(
      backgroundColor: AppColors.darkBG,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "DESAFIO PRÁTICO",
          style: TextStyle(
            color: AppColors.neonOrange,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: FadeInSlide(
                duration: const Duration(milliseconds: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ícone em destaque
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.neonOrange.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.neonOrange.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: AppColors.neonOrange,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'PREPARE-SE!',
                      style: TextStyle(
                        color: AppColors.neonOrange,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Mostre seus sinais em Libras para a câmera e teste seus reflexos em tempo real!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 15,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Card de Regras
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _ruleRow(
                            Icons.front_hand_rounded,
                            AppColors.neonBlue,
                            'Posicione a mão visível na câmera',
                          ),
                          const SizedBox(height: 16),
                          _ruleRow(
                            Icons.timer_rounded,
                            AppColors.neonOrange,
                            '$_challengeTimeLeft segundos por sinal sorteado',
                          ),
                          const SizedBox(height: 16),
                          _ruleRow(
                            Icons.check_circle_outline_rounded,
                            AppColors.neonGreen,
                            'Sustente o sinal por $_secondsToHold segundos',
                          ),
                          const SizedBox(height: 16),
                          _ruleRow(
                            Icons.star_rounded,
                            AppColors.neonGold,
                            '${widget.lessons.length} sinais sorteados nesta rodada',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Botão Começar Desafio
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _startChallenge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonOrange,
                          foregroundColor: Colors.black,
                          elevation: 8,
                          shadowColor: AppColors.neonOrange.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Começar Desafio',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ruleRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
