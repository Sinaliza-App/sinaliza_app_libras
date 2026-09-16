import 'package:flutter_test/flutter_test.dart';
import 'package:sinaliza_app_libras/services/libras_inference_service.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Teste de inicialização do LibrasInferenceService e leitura do JSON com 31 classes', () async {
    final service = LibrasInferenceService();
    
    // Testa se o inicializador não joga exceções (carrega o .onnx corretamente)
    try {
      await service.initialize();
      expect(true, isTrue); // Passa se não houver erro
    } catch (e) {
      fail('A inicialização lançou uma exceção: $e');
    }

    // Verifica se os sinais estão sendo mapeados corretamente
    // 0: "azul", etc. Vamos pegar o nome de alguns índices, dependendo de como o JSON está
    // Mas primeiro, vamos testar se não retorna 'Desconhecido' para vários índices.
    
    // Lemos o JSON nativamente no teste só pra saber qual a length esperada
    final jsonString = await rootBundle.loadString('assets/models/class_map_lstm.json');
    expect(jsonString, isNotEmpty);
    
    // Pelo que diz na issue, strings como azul, comer, beber, gato, trabalhar, obrigado estão lá.
    // Vamos verificar se algumas delas são encontradas no mapeamento testando índices do 0 ao 30
    bool hasAzul = false;
    bool hasObrigado = false;
    bool hasGato = false;
    
    for (int i = 0; i < 31; i++) {
      final name = service.getSignName(i);
      print('Índice $i -> $name');
      if (name.toLowerCase() == 'azul') hasAzul = true;
      if (name.toLowerCase() == 'obrigado') hasObrigado = true;
      if (name.toLowerCase() == 'gato') hasGato = true;
    }
    
    expect(hasAzul, isTrue, reason: 'Deveria conter azul no class_map');
    expect(hasObrigado, isTrue, reason: 'Deveria conter obrigado no class_map');
    expect(hasGato, isTrue, reason: 'Deveria conter gato no class_map');
  });
}
