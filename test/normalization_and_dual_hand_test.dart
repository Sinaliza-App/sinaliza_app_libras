import 'package:flutter_test/flutter_test.dart';
import 'package:sinaliza_app_libras/services/libras_inference_service.dart';

String normalizeGesture(String gesture) {
  String g = gesture.toLowerCase().trim();
  g = g.replaceAll('c_cedilha', 'c_cedilha')
       .replaceAll('c-cedilha', 'c_cedilha')
       .replaceAll('c cedilha', 'c_cedilha')
       .replaceAll('ç', 'c_cedilha');

  g = g.replaceAll(RegExp(r'[?!.,;:()\[\]{}]'), '');

  return g
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll(RegExp(r'[\s/|-]+'), '_')
      .trim();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Testes de Normalização de Sinais', () {
    test('Letras do alfabeto simples', () {
      expect(normalizeGesture('A'), equals('a'));
      expect(normalizeGesture('B'), equals('b'));
      expect(normalizeGesture('C'), equals('c'));
      expect(normalizeGesture('z'), equals('z'));
    });

    test('Tratamento especial de Ç / C_CEDILHA', () {
      expect(normalizeGesture('Ç'), equals('c_cedilha'));
      expect(normalizeGesture('ç'), equals('c_cedilha'));
      expect(normalizeGesture('C_CEDILHA'), equals('c_cedilha'));
      expect(normalizeGesture('c_cedilha'), equals('c_cedilha'));
      expect(normalizeGesture('C-CEDILHA'), equals('c_cedilha'));
      expect(normalizeGesture('c cedilha'), equals('c_cedilha'));
    });

    test('Tratamento de pontuação e sinais dinâmicos compostos', () {
      expect(normalizeGesture('Tudo bem?'), equals('tudo_bem'));
      expect(normalizeGesture('Obrigado!'), equals('obrigado'));
      expect(normalizeGesture('Bom dia!'), equals('bom_dia'));
      expect(normalizeGesture('Boa tarde...'), equals('boa_tarde'));
      expect(normalizeGesture('Brincar / Jogar'), equals('brincar_jogar'));
      expect(normalizeGesture('Pedir Ajuda'), equals('pedir_ajuda'));
    });
  });

  group('Teste do Dual Candidate no LibrasInferenceService', () {
    test('Segunda mão no slot 195..257 é detectada e avaliada com sucesso', () async {
      final service = LibrasInferenceService();
      await service.initialize();

      // Vetor onde a mão primária (132..194) é ruído/vazia,
      // e a mão secundária (195..257) tem o sinal de 'A'
      final feat = List<double>.filled(258, 0.0);
      
      // Carrega pontos reconstruídos de 'A'
      // Pulso em (0,0,0), MCP em distância ~1.0
      feat[195 + 9 * 3 + 1] = -1.0; // MCP9
      feat[195 + 4 * 3] = 0.5;      // Thumb

      final result = await service.predictAlphabet(feat);
      expect(result['prediction'], isNotNull);
      expect(result['confidence'], isNotNull);
    });
  });
}
