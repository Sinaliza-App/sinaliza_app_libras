// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:sinaliza_app_libras/services/libras_inference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Teste de inferência LSTM com sequência', () async {
    final service = LibrasInferenceService();
    await service.initialize();

    // Create a 30-frame sequence of 258 features
    final seq = List.generate(30, (frameIdx) {
      final frame = List<double>.filled(258, 0.0);
      // Let's add some movement in left hand (132..194)
      for (int i = 0; i < 21; i++) {
        frame[132 + i * 3] = 0.1 * frameIdx / 30.0;
        frame[132 + i * 3 + 1] = -0.5 + 0.2 * frameIdx / 30.0;
        frame[132 + i * 3 + 2] = 0.05;
      }
      return frame;
    });

    final result = await service.predict(seq);
    print('LSTM Result with moving hand and zero pose: $result');
    expect(result['prediction'], isNot(equals('Nenhum')));
  });
}
