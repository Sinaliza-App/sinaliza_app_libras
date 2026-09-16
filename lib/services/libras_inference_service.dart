import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';

class LibrasInferenceService {
  OrtSession? _session;
  List<String> _classMap = [];

  /// Inicializa o modelo ONNX e o dicionário de sinais.
  Future<void> initialize() async {
    // 1. Inicializa o ambiente do ONNX Runtime
    OrtEnv.instance.init();

    // 2. Carrega o modelo ONNX
    final rawAssetFile = await rootBundle.load('assets/models/modelo_lstm_libras.onnx');
    final bytes = rawAssetFile.buffer.asUint8List(rawAssetFile.offsetInBytes, rawAssetFile.lengthInBytes);
    
    final sessionOptions = OrtSessionOptions();
    _session = OrtSession.fromBuffer(bytes, sessionOptions);

    // 3. Carrega dinamicamente o mapa de classes (agora com 31 classes)
    final jsonString = await rootBundle.loadString('assets/models/class_map_lstm.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    
    // Popula o array de classes com base no tamanho do JSON dinamicamente
    // Evitando hardcode de 10 classes
    _classMap = List<String>.filled(jsonMap.length, '');
    jsonMap.forEach((key, value) {
      final index = int.tryParse(key);
      if (index != null && index < _classMap.length) {
        _classMap[index] = value.toString();
      }
    });
  }

  /// Retorna o nome do sinal predito com base no index
  String getSignName(int index) {
    if (index >= 0 && index < _classMap.length) {
      return _classMap[index];
    }
    return 'Desconhecido';
  }

  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
  }
}
