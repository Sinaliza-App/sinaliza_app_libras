import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';

class LibrasInferenceService {
  static final LibrasInferenceService _instance = LibrasInferenceService._internal();
  factory LibrasInferenceService() => _instance;
  LibrasInferenceService._internal();

  OrtSession? _sessionLstm;
  OrtSession? _sessionMlp;
  List<String> _classMapLstm = [];
  List<String> _classMapMlp = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Inicializa os modelos ONNX e dicionários de sinais.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      OrtEnv.instance.init();
      final sessionOptions = OrtSessionOptions();

      // --- CARREGA LSTM (Palavras) ---
      final rawLstm = await rootBundle.load('assets/models/modelo_lstm_libras.onnx');
      _sessionLstm = OrtSession.fromBuffer(
        rawLstm.buffer.asUint8List(rawLstm.offsetInBytes, rawLstm.lengthInBytes), 
        sessionOptions,
      );
      final jsonLstm = await rootBundle.loadString('assets/models/class_map_lstm.json');
      final mapLstm = json.decode(jsonLstm) as Map<String, dynamic>;
      _classMapLstm = List<String>.filled(mapLstm.length, '');
      mapLstm.forEach((k, v) { if (int.tryParse(k) != null) _classMapLstm[int.parse(k)] = v.toString(); });

      // --- CARREGA MLP (Alfabeto) ---
      final rawMlp = await rootBundle.load('assets/models/modelo_mlp_alfabeto.onnx');
      _sessionMlp = OrtSession.fromBuffer(
        rawMlp.buffer.asUint8List(rawMlp.offsetInBytes, rawMlp.lengthInBytes), 
        sessionOptions,
      );
      final jsonMlp = await rootBundle.loadString('assets/models/class_map_alfabeto.json');
      final decodedMlp = json.decode(jsonMlp);
      if (decodedMlp is List) {
        _classMapMlp = decodedMlp.map((e) => e.toString()).toList();
      } else if (decodedMlp is Map) {
        _classMapMlp = List<String>.filled(decodedMlp.length, '');
        decodedMlp.forEach((k, v) { if (int.tryParse(k.toString()) != null) _classMapMlp[int.parse(k.toString())] = v.toString(); });
      }

      _isInitialized = true;
      debugPrint("🧠 LibrasInferenceService inicializado com sucesso (LSTM + MLP)");
    } catch (e) {
      debugPrint("❌ Erro ao inicializar LibrasInferenceService: $e");
      rethrow;
    }
  }

  /// Retorna o nome do sinal predito com base no index (Retrocompatibilidade com testes)
  String getSignName(int index) {
    if (index >= 0 && index < _classMapLstm.length) {
      return _classMapLstm[index];
    }
    return 'Desconhecido';
  }

  /// Aplica a função Softmax em um array de logits
  List<double> _softmax(List<double> logits) {
    final double maxLogit = logits.reduce((curr, next) => curr > next ? curr : next);
    double sumExp = 0.0;
    final List<double> exps = logits.map((e) {
      final double exp = math.exp(e - maxLogit);
      sumExp += exp;
      return exp;
    }).toList();
    return exps.map((e) => e / sumExp).toList();
  }

  /// Inferência para Palavras (Modelo LSTM)
  /// Inferência para Palavras (Modelo LSTM)
  Future<Map<String, dynamic>> predict(List<List<double>> sequence30x258) async {
    if (_sessionLstm == null || sequence30x258.length != 30) return {'prediction': 'Nenhum', 'confidence': 0.0};
    try {
      final res1 = await _runLstmInternal(sequence30x258);
      final double conf1 = (res1['confidence'] as num?)?.toDouble() ?? 0.0;

      // Se a confiança for menor que 0.85, testamos também o candidato com slots de mão invertidos
      // (caso o usuário esteja usando a mão oposta ou o sinal dinâmico tenha sido treinado no outro slot)
      if (conf1 < 0.85) {
        final swappedSeq = sequence30x258.map((frame) {
          final swappedFrame = List<double>.from(frame);
          for (int i = 0; i < 63; i++) {
            final tmp = swappedFrame[132 + i];
            swappedFrame[132 + i] = swappedFrame[195 + i];
            swappedFrame[195 + i] = tmp;
          }
          return swappedFrame;
        }).toList();

        final res2 = await _runLstmInternal(swappedSeq);
        final double conf2 = (res2['confidence'] as num?)?.toDouble() ?? 0.0;

        if (conf2 > conf1) {
          return res2;
        }
      }

      return res1;
    } catch (e) { 
      debugPrint("❌ Erro no ONNX (LSTM): $e");
      return {'prediction': 'Nenhum', 'confidence': 0.0}; 
    }
  }

  Future<Map<String, dynamic>> _runLstmInternal(List<List<double>> seq) async {
    final flatList = seq.expand((row) => row).toList();
    final inputOrt = OrtValueTensor.createTensorWithDataList(Float32List.fromList(flatList), [1, 30, 258]);
    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = await _sessionLstm!.runAsync(runOptions, {'input': inputOrt});
      final rawProbs = outputs?.first?.value as List<dynamic>?;
      if (rawProbs == null) return {'prediction': 'Nenhum', 'confidence': 0.0};

      final logits = (rawProbs[0] as List).map((e) => (e as num).toDouble()).toList();
      final probs = _softmax(logits);

      double maxProb = -1.0;
      int maxIdx = -1;
      for (int i = 0; i < probs.length; i++) {
        if (probs[i] > maxProb) { maxProb = probs[i]; maxIdx = i; }
      }
      return {'prediction': _classMapLstm[maxIdx], 'confidence': maxProb};
    } finally {
      inputOrt.release();
      runOptions.release();
      if (outputs != null) {
        for (final o in outputs) {
          o?.release();
        }
      }
    }
  }

  /// Inferência para Alfabeto (Modelo MLP)
  Future<Map<String, dynamic>> predictAlphabet(List<double> features258) async {
    if (_sessionMlp == null) return {'prediction': 'Nenhum', 'confidence': 0.0};
    
    final bool isEmpty = features258.every((e) => e == 0.0);
    if (isEmpty) return {'prediction': 'Nenhum', 'confidence': 0.0};
    
    try {
      // 1. Candidato 1: Mão como veio
      final res1 = await _runMlpInternal(features258);

      // 2. Candidato 2: Inversão dos slots de mão (132..194 <-> 195..257)
      // Permite que sinais como Q (treinado no slot direito 195..257) e sinais em qualquer mão
      // obtenham 100% de confiança
      final candidate2 = List<double>.from(features258);
      for (int i = 0; i < 63; i++) {
        final tmp = candidate2[132 + i];
        candidate2[132 + i] = candidate2[195 + i];
        candidate2[195 + i] = tmp;
      }
      final res2 = await _runMlpInternal(candidate2);

      final double conf1 = (res1['confidence'] as num?)?.toDouble() ?? 0.0;
      final double conf2 = (res2['confidence'] as num?)?.toDouble() ?? 0.0;

      return conf2 > conf1 ? res2 : res1;
    } catch (e) {
      debugPrint("❌ Erro no ONNX (MLP): $e");
      return {'prediction': 'Nenhum', 'confidence': 0.0};
    }
  }

  Future<Map<String, dynamic>> _runMlpInternal(List<double> feat) async {
    final inputOrt = OrtValueTensor.createTensorWithDataList(Float32List.fromList(feat), [1, 258]);
    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = await _sessionMlp!.runAsync(runOptions, {'input': inputOrt});
      final rawProbs = outputs?.first?.value as List<dynamic>?;
      if (rawProbs == null) return {'prediction': 'Nenhum', 'confidence': 0.0};

      final logits = (rawProbs[0] as List).map((e) => (e as num).toDouble()).toList();
      final probs = _softmax(logits);

      double maxProb = -1.0;
      int maxIdx = -1;
      for (int i = 0; i < probs.length; i++) {
        if (probs[i] > maxProb) { maxProb = probs[i]; maxIdx = i; }
      }
      return {'prediction': _classMapMlp[maxIdx], 'confidence': maxProb};
    } finally {
      inputOrt.release();
      runOptions.release();
      if (outputs != null) {
        for (final o in outputs) {
          o?.release();
        }
      }
    }
  }

  void dispose() {
    _sessionLstm?.release();
    _sessionMlp?.release();
    _sessionLstm = null;
    _sessionMlp = null;
    OrtEnv.instance.release();
    _isInitialized = false;
  }
}
