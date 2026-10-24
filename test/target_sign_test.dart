// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinaliza_app_libras/services/libras_inference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Teste do novo preditor com targetSign em ambas as maos', () async {
    final service = LibrasInferenceService();
    await service.initialize();

    final file = File('test/reconstructed_alphabet.json');
    final jsonContent = await file.readAsString();
    final data = json.decode(jsonContent) as Map<String, dynamic>;

    int correctLeft = 0;
    int correctRight = 0;

    for (final entry in data.entries) {
      final letter = entry.key;
      final rawPoints = entry.value as List<dynamic>;

      // Test Hand in Left Slot (132..194)
      final featLeft = List<double>.filled(258, 0.0);
      for (int i = 0; i < 21; i++) {
        final pt = rawPoints[i] as List<dynamic>;
        featLeft[132 + i * 3] = (pt[0] as num).toDouble();
        featLeft[132 + i * 3 + 1] = (pt[1] as num).toDouble();
        featLeft[132 + i * 3 + 2] = (pt[2] as num).toDouble();
      }

      // Test Hand in Right Slot (195..257)
      final featRight = List<double>.filled(258, 0.0);
      for (int i = 0; i < 21; i++) {
        final pt = rawPoints[i] as List<dynamic>;
        featRight[195 + i * 3] = (pt[0] as num).toDouble();
        featRight[195 + i * 3 + 1] = (pt[1] as num).toDouble();
        featRight[195 + i * 3 + 2] = (pt[2] as num).toDouble();
      }

      final resL = await service.predictAlphabet(featLeft);
      if (resL['prediction'] == letter) correctLeft++;

      final resR = await service.predictAlphabet(featRight);
      if (resR['prediction'] == letter) correctRight++;
    }

    print('Acertos atuais sem targetSign: Left=$correctLeft / 27, Right=$correctRight / 27');
  });
}
