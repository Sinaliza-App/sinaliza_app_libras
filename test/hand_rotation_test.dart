// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinaliza_app_libras/services/libras_inference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Teste de variações geométricas em C', () async {
    final service = LibrasInferenceService();
    await service.initialize();

    final file = File('test/reconstructed_alphabet.json');
    final jsonContent = await file.readAsString();
    final data = json.decode(jsonContent) as Map<String, dynamic>;

    final rawPointsC = data['C'] as List<dynamic>;

    // 1. Normal C (0 deg, correct flip)
    void testVariant(String name, double Function(double x, double y) getX, double Function(double x, double y) getY) async {
      final feat = List<double>.filled(258, 0.0);
      for (int i = 0; i < 21; i++) {
        final pt = rawPointsC[i] as List<dynamic>;
        final x = (pt[0] as num).toDouble();
        final y = (pt[1] as num).toDouble();
        final z = (pt[2] as num).toDouble();

        feat[132 + i * 3] = getX(x, y);
        feat[132 + i * 3 + 1] = getY(x, y);
        feat[132 + i * 3 + 2] = z;
      }

      final result = await service.predictAlphabet(feat);
      print('$name -> ${result['prediction']} (${((result['confidence'] as num) * 100).toStringAsFixed(1)}%)');
    }

    testVariant('Normal C', (x, y) => x, (x, y) => y);
    testVariant('Flip X (-x, y)', (x, y) => -x, (x, y) => y);
    testVariant('Flip Y (x, -y)', (x, y) => x, (x, y) => -y);
    testVariant('Swap X,Y (y, x)', (x, y) => y, (x, y) => x);
    testVariant('Swap X,Y + flip X (-y, x)', (x, y) => -y, (x, y) => x);
    testVariant('Swap X,Y + flip Y (y, -x)', (x, y) => y, (x, y) => -x);
    testVariant('Swap X,Y + flip both (-y, -x)', (x, y) => -y, (x, y) => -x);
    testVariant('Flip both (-x, -y)', (x, y) => -x, (x, y) => -y);
  });
}
