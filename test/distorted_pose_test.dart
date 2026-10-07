// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinaliza_app_libras/services/libras_inference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Teste do impacto do Pose distorcido nas classes', () async {
    final service = LibrasInferenceService();
    await service.initialize();

    final file = File('test/reconstructed_alphabet.json');
    final jsonContent = await file.readAsString();
    final data = json.decode(jsonContent) as Map<String, dynamic>;

    // Simulated distorted pose from vision_extractor_service.dart
    // where shoulders are vertical, scale is distorted, etc.
    final distortedPose = List<double>.filled(132, 0.0);
    // Shoulder 11 (left) and 12 (right) rotated 90 deg and scaled
    distortedPose[11 * 4] = 0.0;
    distortedPose[11 * 4 + 1] = 0.5;
    distortedPose[12 * 4] = 0.0;
    distortedPose[12 * 4 + 1] = -0.5;
    for (int i = 0; i < 33; i++) {
      distortedPose[i * 4 + 3] = 0.99; // visibility
    }

    int correct = 0;
    int pCount = 0;
    for (final entry in data.entries) {
      final letter = entry.key;
      final rawPoints = entry.value as List<dynamic>;

      final feat = List<double>.filled(258, 0.0);
      // Put distorted pose:
      for (int i = 0; i < 132; i++) {
        feat[i] = distortedPose[i];
      }
      // Put hand points:
      for (int i = 0; i < 21; i++) {
        final pt = rawPoints[i] as List<dynamic>;
        feat[132 + i * 3] = (pt[0] as num).toDouble();
        feat[132 + i * 3 + 1] = (pt[1] as num).toDouble();
        feat[132 + i * 3 + 2] = (pt[2] as num).toDouble();
      }

      final result = await service.predictAlphabet(feat);
      final pred = result['prediction'];
      final conf = (result['confidence'] as num).toDouble();
      if (pred == letter) correct++;
      if (pred == 'P') pCount++;
      print('Classe $letter -> Predito com Pose Distorcido: $pred (${(conf * 100).toStringAsFixed(1)}%)');
    }

    print('\nTotal Acertos com Pose Distorcido: $correct / ${data.length}, Quantidade que deu P: $pCount');
  });
}
