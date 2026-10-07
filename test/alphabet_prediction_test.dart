// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinaliza_app_libras/services/libras_inference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Teste de todas as 27 classes do alfabeto com LibrasInferenceService', () async {
    final service = LibrasInferenceService();
    await service.initialize();

    final file = File('test/reconstructed_alphabet.json');
    final jsonContent = await file.readAsString();
    final data = json.decode(jsonContent) as Map<String, dynamic>;

    int correct = 0;
    for (final entry in data.entries) {
      final letter = entry.key;
      final rawPoints = entry.value as List<dynamic>;

      final feat = List<double>.filled(258, 0.0);
      for (int i = 0; i < 21; i++) {
        final pt = rawPoints[i] as List<dynamic>;
        feat[132 + i * 3] = (pt[0] as num).toDouble();
        feat[132 + i * 3 + 1] = (pt[1] as num).toDouble();
        feat[132 + i * 3 + 2] = (pt[2] as num).toDouble();
      }

      final result = await service.predictAlphabet(feat);
      final pred = result['prediction'];
      final conf = (result['confidence'] as num).toDouble();
      final isMatch = pred == letter;
      if (isMatch) correct++;
      print('Classe $letter -> Predito: $pred (${(conf * 100).toStringAsFixed(1)}%) ${isMatch ? "✅" : "❌"}');
    }

    print('\nTotal Acertos: $correct / ${data.length}');
    expect(correct, equals(data.length));
  });
}
