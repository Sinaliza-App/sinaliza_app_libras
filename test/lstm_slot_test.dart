// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'dart:math' as math;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Inspecao de Comportamento do Modelo LSTM', () async {
    OrtEnv.instance.init();
    final sessionOptions = OrtSessionOptions();
    final rawLstm = await rootBundle.load('assets/models/modelo_lstm_libras.onnx');
    final session = OrtSession.fromBuffer(
      rawLstm.buffer.asUint8List(rawLstm.offsetInBytes, rawLstm.lengthInBytes),
      sessionOptions,
    );
    final jsonLstm = await rootBundle.loadString('assets/models/class_map_lstm.json');
    final mapLstm = json.decode(jsonLstm) as Map<String, dynamic>;
    final classMap = List<String>.filled(mapLstm.length, '');
    mapLstm.forEach((k, v) { if (int.tryParse(k) != null) classMap[int.parse(k)] = v.toString(); });

    print('Classes LSTM (${classMap.length}): $classMap');

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

    Future<(String, double)> runLstm(List<List<double>> seq) async {
      final flat = seq.expand((e) => e).toList();
      final inputOrt = OrtValueTensor.createTensorWithDataList(Float32List.fromList(flat), [1, 30, 258]);
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

    // Test with completely empty sequence (all zeros)
    final zerosSeq = List.generate(30, (_) => List<double>.filled(258, 0.0));
    final (predZero, confZero) = await runLstm(zerosSeq);
    print('Sequência de Zeros -> Predição: $predZero (${(confZero*100).toStringAsFixed(1)}%)');

    // Test with moving hand in Slot 132..194 (left)
    final seqLeft = List.generate(30, (frameIdx) {
      final frame = List<double>.filled(258, 0.0);
      final t = frameIdx / 29.0;
      // Shoulder pose normalized: sh_mid=(0,0,0), sh_dist=1.0 -> sh_left=[-0.5, 0, 0], sh_right=[0.5, 0, 0]
      frame[11 * 4] = -0.5;
      frame[12 * 4] = 0.5;
      for (int i = 0; i < 33; i++) {
        frame[i * 4 + 3] = 0.95; // visibility
      }
      // Hand moving
      for (int i = 0; i < 21; i++) {
        frame[132 + i * 3] = math.sin(t * math.pi) * 0.3;
        frame[132 + i * 3 + 1] = -0.3 + t * 0.4;
        frame[132 + i * 3 + 2] = 0.1;
      }
      return frame;
    });
    final (predL, confL) = await runLstm(seqLeft);
    print('Mão se movendo no slot 132 (Pose normalizada): $predL (${(confL*100).toStringAsFixed(1)}%)');

    // Test same movement in Slot 195..257 (right)
    final seqRight = List.generate(30, (frameIdx) {
      final frame = List<double>.filled(258, 0.0);
      final t = frameIdx / 29.0;
      frame[11 * 4] = -0.5;
      frame[12 * 4] = 0.5;
      for (int i = 0; i < 33; i++) {
        frame[i * 4 + 3] = 0.95;
      }
      for (int i = 0; i < 21; i++) {
        frame[195 + i * 3] = math.sin(t * math.pi) * 0.3;
        frame[195 + i * 3 + 1] = -0.3 + t * 0.4;
        frame[195 + i * 3 + 2] = 0.1;
      }
      return frame;
    });
    final (predR, confR) = await runLstm(seqRight);
    print('Mão se movendo no slot 195 (Pose normalizada): $predR (${(confR*100).toStringAsFixed(1)}%)');
  });
}
