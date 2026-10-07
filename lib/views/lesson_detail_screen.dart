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
import 'package:provider/provider.dart';
import 'package:sinaliza_app_libras/providers/user_provider.dart';

import 'package:sinaliza_app_libras/widgets/custom_snackbar.dart';
import 'package:sinaliza_app_libras/widgets/streak_dialog.dart';
import 'package:sinaliza_app_libras/services/vision_extractor_service.dart';
import 'package:sinaliza_app_libras/services/libras_inference_service.dart';

class LessonDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lesson;

  const LessonDetailScreen({super.key, required this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  // --- IA OFFLINE ---
  final VisionExtractorService _visionExtractor = VisionExtractorService();
  final LibrasInferenceService _inferenceService = LibrasInferenceService();
  final List<List<double>> _frameBuffer = [];

  // --- CÂMERA ---
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessingFrame = false;
  DateTime? _lastFrameTime;
  bool _isConnected = false;

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
  bool _isSavingProgress = false;
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _extractTargetGesture();
    _initializeCamera();
    _initializeLocalAI();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
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
    if (widget.lesson['sign_name'] != null && widget.lesson['sign_name'].toString().trim().isNotEmpty) {
      _targetGesture = widget.lesson['sign_name'].toString().trim();
    } else {
      final title = widget.lesson['title'].toString();
      if (title.contains("Letra ")) {
        _targetGesture = title.split("Letra ").last.trim();
      } else {
        _targetGesture = title.split(":").last.trim();
      }
    }
    
    // Regra Inteligente: Se for movimento, o usuário ganha instantaneamente (0s).
    // Se for estático (Alfabeto), ele precisa segurar a pose (2s).
    final lessonType = (widget.lesson['type'] ?? 'estatico').toString().toLowerCase();
    _isMovement = lessonType == 'movimento' || lessonType == 'dynamic';
    _secondsToHold = _isMovement ? 0 : 1;
  }

  @override
  void dispose() {
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
    } catch (e) {
      debugPrint("Erro ao iniciar câmera: $e");
    }
  }

  Future<void> _reportError() async {
    if (_lastLandmarks.isEmpty || _lastLandmarks.length != 30) {
      CustomSnackBar.showError(context, "Nenhum dado capturado ainda. Aguarde.");
      return;
    }
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final payload = {
        "user_id": userId,
        "sign_name": _targetGesture,
        "source": "mobile_feedback",
        "reporter_role": "student",
        "raw_landmarks": _lastLandmarks
      };

      final response = await ApiService.post('$apiBaseUrl/coleta/amostra', body: jsonEncode(payload));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (userId != null) {
          final res = await Supabase.instance.client.from('profiles').select('total_score').eq('id', userId).single();
          final currentScore = res['total_score'] as int? ?? 0;
          await Supabase.instance.client.from('profiles').update({'total_score': currentScore + 10}).eq('id', userId);
        }
        if (mounted) {
          Provider.of<UserProvider>(context, listen: false).addScore(10);
          CustomSnackBar.showSuccess(context, "Amostra enviada para revisão do professor! +10 XP");
        }
      } else {
        if (mounted) CustomSnackBar.showError(context, "Erro ao enviar amostra: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, "Erro de rede ao reportar incorreção.");
    }
  }

  // --- INFERÊNCIA OFFLINE OTIMIZADA (SEM TRAVAMENTO DE PREVIEW) ---
  void _startVisionStream() {
    _cameraController!.startImageStream((CameraImage image) {
      // Retorna em 0.001ms para nunca prender a thread de preview da câmera nativa
      if (!_isConnected || _isProcessingFrame || _isCorrect) return;

      final now = DateTime.now();
      // Throttle: 35ms para dinâmico (~28 FPS para 30 frames em ~1s) e 70ms para estático (~14 FPS)
      final int throttleMs = _isMovement ? 35 : 70;
      if (_lastFrameTime != null && now.difference(_lastFrameTime!).inMilliseconds < throttleMs) {
        return; 
      }
      
      _lastFrameTime = now;
      _isProcessingFrame = true;

      // Desacopla o processamento computacional pesado da fila da câmera
      _processFrameAsync(image);
    });
  }

  Future<void> _processFrameAsync(CameraImage image) async {
    try {
      // 1. Extrai o frame (Usa a normalização e espelhamento já criados)
      final int sensorOrientation = _cameraController!.description.sensorOrientation;
      final lensDirection = _cameraController!.description.lensDirection;
      final features = await _visionExtractor.processImage(
        image, 
        sensorOrientation,
        isMovement: _isMovement,
        lensDirection: lensDirection,
      );

      // Se o array voltar vazio/zerado (mão não detectada)
      if (features.every((element) => element == 0.0)) {
        final now = DateTime.now();
        if (_lastMatchTime == null || now.difference(_lastMatchTime!).inMilliseconds > 450) {
          if (_detectedGesture != "Nenhum") {
            _handleDetectionResult("Nenhum", 0.0);
          }
        }
        return;
      }

      if (mounted) {
        // 2. Bufferização
        _frameBuffer.add(features);
        if (_frameBuffer.length > 30) {
          _frameBuffer.removeAt(0);
        }

        _lastLandmarks = List.from(_frameBuffer);

        // 3. Inferência local no ONNX
        if (!_isMovement) {
          // Alfabeto (MLP): Usa apenas o frame atual
          final result = await _inferenceService.predictAlphabet(features);
          debugPrint("📝 Resultado Alfabeto: $result");
          
          final String gesture = (result['prediction'] as String?) ?? "Nenhum";
          final double confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
          
          _handleDetectionResult(gesture, confidence);
        } else {
          // Gestos (LSTM): Requer o buffer completo de 30 frames
          if (_frameBuffer.length == 30) {
            final result = await _inferenceService.predict(_frameBuffer);
            debugPrint("🏃‍♂️ Resultado Movimento: $result");
            
            final String gesture = (result['prediction'] as String?) ?? "Nenhum";
            final double confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
            
            _handleDetectionResult(gesture, confidence);
          }
        }
      }
    } catch (e) {
      debugPrint("Erro no processamento do frame: $e");
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
    final String normalizedDetected = _normalizeGesture(gesture);
    final String normalizedTarget = _normalizeGesture(_targetGesture);

    debugPrint("🎯 Validando: '$normalizedDetected' vs '$normalizedTarget' (Confiança: $confidence)");

    final double minConfidence = _isMovement ? 0.35 : 0.40;
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
          _secondsHeld = now.difference(_firstDetectionTime!).inSeconds;
        }

        // Se bateu a meta (ex: 1 segundo para estático ou instantâneo para movimento)
        if (_secondsHeld >= _secondsToHold) {
          _isCorrect = true;
          _onSuccess();
        }
      }
    } else {
      if (!_isCorrect) {
        // Tolerância de 700ms antes de zerar o progresso
        // Evita que variações rápidas de luz ou micro-tremores zerem a contagem
        if (_lastMatchTime == null || now.difference(_lastMatchTime!).inMilliseconds > 700) {
          _firstDetectionTime = null;
          _secondsHeld = 0;
        }
      }
    }

    // Atualiza a tela com o que a IA está enxergando agora
    setState(() {
      _detectedConfidence = confidence;
      if (confidence >= (_isMovement ? 0.35 : 0.40)) {
        _detectedGesture = gesture;
      } else {
        _detectedGesture = "Aguardando...";
      }
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
    if (!_isCorrect) return;

    setState(() {
      _isSavingProgress = true;
    });

    final String apiUrl = '$apiBaseUrl/progress';

    try {
      final response = await ApiService.post(
            apiUrl,
            body: json.encode({'lesson_id': widget.lesson['id'], 'score': 10}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      final responseData = json.decode(response.body);

      final currentStreak = Provider.of<UserProvider>(context, listen: false).user?.streakCount ?? 0;
      bool showedCelebration = false;

      // Atualiza a ofensiva em qualquer caso de sucesso (201 ou 200)
      if (responseData['streak_count'] != null) {
        final int newStreak = responseData['streak_count'] as int;
        Provider.of<UserProvider>(context, listen: false).updateStreak(newStreak);

        // Se a ofensiva aumentou de verdade (usuário concluiu a primeira lição do dia)
        if (newStreak > currentStreak) {
          await StreakDialog.show(context, newStreak);
          showedCelebration = true;
          if (!mounted) return;
        }
      }

      if (response.statusCode == 201) {
        Provider.of<UserProvider>(context, listen: false).addScore(10);
        if (!showedCelebration) {
          CustomSnackBar.showSuccess(
            context,
            (responseData['message'] as String?) ?? 'Progresso salvo! +10 XP',
          );
        }
        Navigator.pop(context, true);
      } else if (response.statusCode == 200 || response.statusCode == 409) {
        if (!showedCelebration) {
          CustomSnackBar.showWarning(
            context,
            (responseData['message'] as String?) ?? 'Você já concluiu esta lição.',
          );
        }
        Navigator.pop(context, true);
      } else {
        CustomSnackBar.showError(context, 'Erro ao salvar progresso.');
      }
    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, 'Erro: $e');
    } finally {
      if (mounted) setState(() => _isSavingProgress = false);
    }
  }

  Color _getStatusColor() {
    if (_isCorrect) return AppColors.neonGreen;
    if (_firstDetectionTime != null) return AppColors.neonOrange;
    return Colors.white.withValues(alpha: 0.2);
  }

  @override
  Widget build(BuildContext context) {
    final String lessonTitle = (widget.lesson['title'] as String?) ?? 'Lição';
    // Prioriza os campos onde o GIF ou animação podem estar armazenados antes de pegar a foto estática
    final String? helpImageUrl = (widget.lesson['gif_url'] as String?) ?? (widget.lesson['example_image_url'] as String?) ?? (widget.lesson['video_url'] as String?) ?? (widget.lesson['thumbnail_url'] as String?);
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
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          if (helpImageUrl != null) const SizedBox(width: 48), // Balanceia os 2 ícones da direita
                          Expanded(
                            child: Text(
                              lessonTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.neonGreen,
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
                                  await Supabase.instance.client.from('reports').insert({
                                    'user_id': userId,
                                    'target_type': 'lesson',
                                    'target_id': widget.lesson['id'],
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
                          helpImageUrl != null
                              ? IconButton(
                                  icon: const Icon(Icons.help_outline, color: AppColors.neonOrange),
                                  onPressed: () => _showHelpDialog(context, helpImageUrl),
                                )
                              : const SizedBox(width: 0),
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
                              Shadow(color: AppColors.neonGreen.withValues(alpha: 0.6), blurRadius: 15),
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
                              if (!_isConnected)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  child: const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(color: AppColors.neonGreen),
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

                    const SizedBox(height: 12),

                    // Botão Principal
                    _isSavingProgress
                        ? const Center(child: CircularProgressIndicator(color: AppColors.neonGreen))
                        : SizedBox(
                            width: double.infinity,
                            height: 54,
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
                                backgroundColor: _isCorrect ? AppColors.neonGreen : AppColors.cardDark,
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
                    const SizedBox(height: 8),
                    
                    // Botão Reportar (Compacto)
                    SizedBox(
                      height: 40,
                      child: TextButton.icon(
                        icon: const Icon(Icons.report_problem, color: AppColors.neonOrange, size: 20),
                        label: const Text(
                          "Reportar Incorreção",
                          style: TextStyle(
                            color: AppColors.neonOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: _reportError,
                      ),
                    ),
                    const SizedBox(height: 8),
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

  void _showHelpDialog(BuildContext context, String imageUrl) {
    final bool isNetwork = imageUrl.startsWith('http');

    showDialog<dynamic>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.darkBG2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Como fazer o sinal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isNetwork 
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image_not_supported, color: Colors.grey, size: 100);
                      },
                    )
                  : Image.asset(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image_not_supported, color: Colors.grey, size: 100);
                      },
                    ),
              ),
              const SizedBox(height: 16),
              const Text('Assista ao movimento e tente repeti-lo para a câmera.', 
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ENTENDI', style: TextStyle(color: AppColors.neonGreen, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}