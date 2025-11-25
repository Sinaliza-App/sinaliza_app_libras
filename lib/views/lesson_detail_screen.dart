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
  bool _isCorrect = false; // <--- NOVA VARIÁVEL: O usuário acertou?
  String _targetGesture = ""; // <--- A resposta correta esperada

  // Progresso
  bool _isSavingProgress = false;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _extractTargetGesture(); // 1. Descobre qual é o gesto correto
    _initializeCamera();
  }

  // 1. Lógica para extrair a resposta correta do Título da Lição
  void _extractTargetGesture() {
    final title = widget.lesson['title'].toString();
    
    // Exemplo: Se o título for "Alfabeto: Letra A", a meta é "A"
    if (title.contains("Letra ")) {
      _targetGesture = title.split("Letra ").last.trim();
    } else {
      // Se for "Saudações: Oi", a meta é "Oi"
      // (Ajuste essa lógica conforme seus títulos no banco)
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
      // ATENÇÃO: Use o IP correto (Radmin ou 10.0.2.2)
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

        // 2. LÓGICA DE COMPARAÇÃO (O Coração do Jogo)
        bool hit = false;
        
        // Só valida se tiver confiança razoável (ex: > 60%)
        if (confidence > 0.7 && gesture == _targetGesture) {
          hit = true;
        }

        setState(() {
          _detectedGesture = gesture;
          _detectedConfidence = confidence;
          
          // Se acertou uma vez, mantém acertado (para não piscar)
          if (hit) _isCorrect = true; 
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
    setState(() {
      _isSavingProgress = true;
    });
    final token = await _storage.read(key: 'jwt_token');
    
    // ... (código de chamada da API POST /progress - IDÊNTICO AO ANTERIOR)
    if (token == null) { /*...*/ return; }
    
    const String apiUrl = 'http://10.0.2.2:3000/progress';
    final int lessonId = widget.lesson['id'];

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'lesson_id': lessonId}),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      
      if (response.statusCode == 201 || response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parabéns! Lição Concluída! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); 
      } else {
        // ... erro
      }
    } catch (e) {
      // ... erro
    } finally {
      setState(() { _isSavingProgress = false; });
    }
  }

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
              _targetGesture, // Mostra apenas a meta (ex: "A")
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
                  // Borda verde se acertou, cinza se não
                  border: Border.all(
                    color: _isCorrect ? Colors.green : Colors.grey,
                    width: _isCorrect ? 4 : 1,
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
            
            // --- FEEDBACK VISUAL ---
            Center(
              child: Column(
                children: [
                  Text(
                    _isCorrect ? "CORRETO! 🎉" : "Tentando detectar...",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _isCorrect ? Colors.green : Colors.grey,
                    ),
                  ),
                  if (!_isCorrect && _detectedGesture != "Nenhum")
                    Text(
                      "Detectado: $_detectedGesture (${(_detectedConfidence*100).toInt()}%)",
                      style: const TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // --- BOTÃO DE CONCLUIR (BLOQUEADO ATÉ ACERTAR) ---
            _isSavingProgress
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: Icon(_isCorrect ? Icons.check_circle : Icons.lock),
                    label: Text(_isCorrect ? 'Concluir Lição' : 'Faça o sinal correto'),
                    // O botão fica null (desabilitado) se _isCorrect for falso
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