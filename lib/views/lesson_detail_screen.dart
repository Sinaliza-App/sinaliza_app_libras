import 'dart:async'; 
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class LessonDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lesson;
  const LessonDetailScreen({super.key, required this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  // Câmera
  CameraController? _cameraController;
  late Future<void> _initializeControllerFuture;
  bool _isCameraInitialized = false;

  // WebSocket e Jogo
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  bool _isStreaming = false;
  
  // Estado do Jogo
  String _detectedGesture = "Posicione a mão...";
  double _detectedConfidence = 0.0;
  bool _isCorrect = false; // O usuário já venceu?
  String _targetGesture = ""; // A resposta correta esperada

  // Variáveis do Temporizador (Gamificação)
  DateTime? _firstDetectionTime; // Quando o usuário começou a acertar
  final int _secondsToHold = 3;  // Tempo necessário para segurar o gesto
  int _secondsHeld = 0;          // Contador para exibir na tela

  // Progresso
  bool _isSavingProgress = false;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _extractTargetGesture(); // Descobre qual é o gesto correto
    _initializeCamera();
  }

  // Lógica para extrair a resposta correta do Título da Lição
  void _extractTargetGesture() {
    final title = widget.lesson['title'].toString();
    
    // Exemplo: Se o título for "Alfabeto: Letra A", a meta é "A"
    if (title.contains("Letra ")) {
      _targetGesture = title.split("Letra ").last.trim();
    } else {
      // Se for "Saudações: Oi", a meta é "Oi"
      _targetGesture = title.split(":").last.trim();
    }
    print("Meta da Lição: $_targetGesture");
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _channel?.sink.close();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    super.dispose();
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
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    _initializeControllerFuture = _cameraController!.initialize();

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
      // ATENÇÃO: Use '10.0.2.2' (Emulador Android) ou o IP do Radmin VPN
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

        // --- LÓGICA DE TEMPORIZADOR E VALIDAÇÃO ---
        bool isCurrentlyMatching = false;
        
        // Verifica se o gesto atual bate com a meta e tem confiança > 60%
        if (confidence > 0.6 && gesture == _targetGesture) {
          isCurrentlyMatching = true;
        }

        if (isCurrentlyMatching) {
          // Se começou a acertar agora, marca o tempo inicial
          _firstDetectionTime ??= DateTime.now();
          
          // Calcula quanto tempo passou
          final duration = DateTime.now().difference(_firstDetectionTime!);
          _secondsHeld = duration.inSeconds;

          // Se segurou pelo tempo necessário...
          if (_secondsHeld >= _secondsToHold) {
            _isCorrect = true; // VENCEU!
          }
        } else {
          // Se parou de acertar (ou errou), zera o cronômetro
          if (!_isCorrect) { // Só zera se ainda não tiver vencido
             _firstDetectionTime = null;
             _secondsHeld = 0;
          }
        }
        // -----------------------------

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
    // Só permite salvar se o usuário tiver acertado
    if (!_lessonCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você precisa acertar o gesto primeiro!')),
      );
      return;
    }

    setState(() { _isSavingProgress = true; });
    final token = await _storage.read(key: 'jwt_token');
    
    if (token == null) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro de autenticação')));
      setState(() { _isSavingProgress = false; });
      return; 
    }
    
    const String apiUrl = 'http://10.0.2.2:3000/progress';
    final int lessonId = widget.lesson['id'];
    
    // Definindo a pontuação (XP) fixa por enquanto
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
          'score': scoreEarned, // Enviando a pontuação
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      
      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        // SUCESSO
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Progresso salvo! +$scoreEarned XP'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context); 
      } else if (response.statusCode == 409) {
        // JÁ SALVO
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você já completou esta lição.')),
        );
        Navigator.pop(context);
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar.')));
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro de conexão: $e')));
    } finally {
      setState(() { _isSavingProgress = false; });
    }
  }
  
  // Getter auxiliar para facilitar leitura no build
  bool get _lessonCorrect => _isCorrect;

  @override
  Widget build(BuildContext context) {
    final String lessonTitle = widget.lesson['title'] ?? 'Lição';

    return Scaffold(
      appBar: AppBar(title: Text(lessonTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Faça o sinal para:',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            Text(
              _targetGesture, 
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // --- ÁREA DA CÂMERA ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  // Borda muda de cor baseado no estado do jogo
                  border: Border.all(
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
            
            // --- FEEDBACK VISUAL DO JOGO ---
            Center(
              child: Column(
                children: [
                  if (_isCorrect)
                    const Text("PARABÉNS! 🎉", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green))
                  
                  else if (_firstDetectionTime != null)
                     // Contagem regressiva
                    Text(
                      "Segure... ${_secondsHeld + 1}/$_secondsToHold",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                    )
                  
                  else if (_detectedGesture != "Nenhum")
                    Text(
                      "Detectado: $_detectedGesture",
                      style: const TextStyle(color: Colors.red, fontSize: 18),
                    )
                  
                  else
                    const Text("Posicione a mão...", style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // --- BOTÃO DE CONCLUIR (BLOQUEADO ATÉ VENCER) ---
            _isSavingProgress
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: Icon(_isCorrect ? Icons.check_circle : Icons.lock),
                    label: Text(_isCorrect ? 'Concluir Lição (+10 XP)' : 'Acerte o sinal para liberar'),
                    // O botão só ativa se _isCorrect for true
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
    );
  }
}