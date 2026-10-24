// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'dart:math' as math;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Comparacao de slots Left (132) vs Right (195)', () async {
    OrtEnv.instance.init();
    final sessionOptions = OrtSessionOptions();
    final rawMlp = await rootBundle.load('assets/models/modelo_mlp_alfabeto.onnx');
    final session = OrtSession.fromBuffer(
      rawMlp.buffer.asUint8List(rawMlp.offsetInBytes, rawMlp.lengthInBytes),
      sessionOptions,
    );
    final jsonMlp = await rootBundle.loadString('assets/models/class_map_alfabeto.json');
    final classMap = (json.decode(jsonMlp) as List).map((e) => e.toString()).toList();

    final file = File('test/reconstructed_alphabet.json');
    final jsonContent = await file.readAsString();
    final data = json.decode(jsonContent) as Map<String, dynamic>;

    List<double> softmax(List<double> logits) {
      final double maxLogit = logits.reduce((curr, next) => curr > next ? curr : next);
      double sumExp = 0.0;
      final List<double> exps = logits.map((e) {
        final double exp = math.exp(e - maxLogit);
        sumExp += exp;
        return exp;
      }).toList();
      return exps.map((e) => e / sumExp).toList();
    }

    Future<(String, double)> runMlp(List<double> feat) async {
      final inputOrt = OrtValueTensor.createTensorWithDataList(Float32List.fromList(feat), [1, 258]);
      final runOptions = OrtRunOptions();
      try {
        final outputs = await session.runAsync(runOptions, {'input': inputOrt});
        final rawProbs = outputs?.first?.value as List<dynamic>?;
        if (rawProbs == null) return ('Nenhum', 0.0);
        final logits = (rawProbs[0] as List).map((e) => (e as num).toDouble()).toList();
        final probs = softmax(logits);
        double maxProb = -1.0;
        int maxIdx = -1;
        for (int i = 0; i < probs.length; i++) {
          if (probs[i] > maxProb) { maxProb = probs[i]; maxIdx = i; }
        }
        return (classMap[maxIdx], maxProb);
      } finally {
        inputOrt.release();
        runOptions.release();
      }
    }

    int leftWins = 0;
    int rightWins = 0;

    for (final entry in data.entries) {
      final letter = entry.key;
      final rawPoints = entry.value as List<dynamic>;

      // Slot LEFT (132..194)
      final featLeft = List<double>.filled(258, 0.0);
      for (int i = 0; i < 21; i++) {
        final pt = rawPoints[i] as List<dynamic>;
        featLeft[132 + i * 3] = (pt[0] as num).toDouble();
        featLeft[132 + i * 3 + 1] = (pt[1] as num).toDouble();
        featLeft[132 + i * 3 + 2] = (pt[2] as num).toDouble();
      }

      // Slot RIGHT (195..257)
      final featRight = List<double>.filled(258, 0.0);
      for (int i = 0; i < 21; i++) {
        final pt = rawPoints[i] as List<dynamic>;
        featRight[195 + i * 3] = (pt[0] as num).toDouble();
        featRight[195 + i * 3 + 1] = (pt[1] as num).toDouble();
        featRight[195 + i * 3 + 2] = (pt[2] as num).toDouble();
      }

      final (predL, confL) = await runMlp(featLeft);
      final (predR, confR) = await runMlp(featRight);

      print('Classe $letter: LEFT -> $predL (${(confL*100).toStringAsFixed(1)}%) | RIGHT -> $predR (${(confR*100).toStringAsFixed(1)}%)');
      if (predL == letter) leftWins++;
      if (predR == letter) rightWins++;
    }

    print('\nAcertos: LEFT slot = $leftWins / ${data.length} | RIGHT slot = $rightWins / ${data.length}');
  });
}
