import 'dart:async'; // Para o StreamSubscription
import 'dart:convert'; // Para jsonEncode, jsonDecode e base64Encode
import 'dart:typed_data'; // Para Uint8List
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart'; // Importe o WebSocket

class LessonDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lesson;
  const LessonDetailScreen({super.key, required this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  // Controladores da Câmera
  CameraController? _cameraController;
  late Future<void> _initializeControllerFuture;
  bool _isCameraInitialized = false;

  // Variáveis do WebSocket
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  bool _isStreaming = false;
  String _detectedGesture = "Aguardando seu sinal...";
  double _detectedConfidence = 0.0;

  // Variáveis de Estado
  bool _isSavingProgress = false;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    // 1. Inicializa a câmera
    _initializeCamera();
  }

  @override
  void dispose() {
    // 6. Limpa tudo ao sair da tela
    _streamSubscription?.cancel(); // Para de ouvir o WebSocket
    _channel?.sink.close(); // Fecha a conexão WebSocket
    _cameraController?.stopImageStream(); // Para o stream da câmera
    _cameraController?.dispose(); // Libera a câmera
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    // Seleciona a câmera frontal (selfie)
    CameraDescription selectedCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false, // Não precisamos de áudio
      imageFormatGroup: ImageFormatGroup.yuv420, // Formato ideal para o stream
    );

    _initializeControllerFuture = _cameraController!.initialize();

    _initializeControllerFuture.then((_) {
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
      
      // 2. Conecta ao WebSocket e inicia o stream de vídeo
      _connectToWebSocket();
      
    }).catchError((e) {
      print("Erro ao inicializar a câmera: $e");
    });
  }

  void _connectToWebSocket() {
    try {
      // 3. Conecta ao servidor WebSocket do Python
      // ATENÇÃO: Use '10.0.2.2' (Emulador Android) ou o IP do Radmin VPN
      final wsUrl = Uri.parse('ws://10.0.2.2:8080');
      _channel = WebSocketChannel.connect(wsUrl);

      // 4. Inicia o stream de imagens da câmera
      _cameraController!.startImageStream((CameraImage image) {
        // Evita sobrecarregar o servidor
        if (_isStreaming) return; 
        _isStreaming = true;

        // Pegue o primeiro plano (Y-plane, escala de cinza)
        final plane = image.planes[0];
        
        // Converta os bytes da imagem para Base64
        final String imageBase64 = base64Encode(plane.bytes);

        // Envie o JSON para o servidor Python
        _channel?.sink.add(jsonEncode({
          'image': imageBase64,
          'height': image.height,
          'width': image.width,
          'stride': plane.bytesPerRow,
        }));
      });

      // 5. Escuta as respostas do servidor Python
      _streamSubscription = _channel?.stream.listen((message) {
        if (!mounted) return;
        
        final data = json.decode(message);
        
        // Atualiza a UI com o gesto detectado
        setState(() {
          _detectedGesture = data['gesto'];
          _detectedConfidence = data['confianca'];
        });

        // Libera para o próximo frame
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

  // --- Função para salvar progresso (sem mudanças) ---
  Future<void> _saveProgress() async {
    setState(() {
      _isSavingProgress = true;
    });

    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Usuário não autenticado.')),
      );
      setState(() {
        _isSavingProgress = false;
      });
      return;
    }

    const String apiUrl = 'http://10.0.2.2:3000/progress';
    final int lessonId = widget.lesson['id'];

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'lesson_id': lessonId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Progresso salvo!')),
        );
        Navigator.pop(context); 
      } else if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Progresso já salvo.')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Erro ao salvar.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: $e')),
      );
    } finally {
      setState(() {
        _isSavingProgress = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final String lessonTitle = widget.lesson['title'] ?? 'Lição';

    return Scaffold(
      appBar: AppBar(
        title: Text(lessonTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pratique o sinal para:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              lessonTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // --- ÁREA DA CÂMERA (LIMPA) ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  // Mostra apenas o preview da câmera, sem o stack de debug
                  child: _isCameraInitialized
                      ? CameraPreview(_cameraController!)
                      : const Center(
                          // Loading da câmera
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // --- FEEDBACK EM TEMPO REAL ---
            Center(
              child: Text(
                _detectedGesture, // Mostra o gesto (ex: "Nenhum" ou "A")
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _detectedConfidence > 0.7 ? Colors.green : Colors.black,
                ),
              ),
            ),
            
            // (Opcional) Mostra a confiança
            if (_detectedConfidence > 0)
              Center(
                child: Text(
                  'Confiança: ${(_detectedConfidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                ),
              ),
            
            const SizedBox(height: 20),
            
            // --- Botão de Concluir Lição (sem mudanças) ---
            _isSavingProgress
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Concluir Lição'),
                    onPressed: _saveProgress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[50],
                      foregroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}