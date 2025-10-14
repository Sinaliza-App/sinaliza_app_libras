import 'package:flutter_test/flutter_test.dart';
import 'package:sinaliza_app_libras/helpers/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    await db.delete('users');
    await db.delete('lessons');
    await db.delete('progress');
  });

  group('Testes do DatabaseHelper', () {
    test('Deve inserir um novo usuário com sucesso', () async {
      final dbHelper = DatabaseHelper();
      final user = {'name': 'João Teste', 'email': 'joao.teste@email.com'};
      
      final id = await dbHelper.insertUser(user);

      expect(id, isPositive, reason: "O ID retornado deveria ser positivo, mas foi 0. Isso indica que o usuário já existia no banco.");

      final db = await dbHelper.database;
      final result = await db.query('users');
      expect(result.length, 1);
      expect(result.first['email'], 'joao.teste@email.com');
    });

    test('Deve retornar 0 ao tentar inserir um email duplicado', () async {
      final dbHelper = DatabaseHelper();
      final user1 = {'name': 'Maria', 'email': 'maria@email.com'};
      final user2 = {'name': 'Maria Outra', 'email': 'maria@email.com'};

      final id1 = await dbHelper.insertUser(user1);
      expect(id1, isPositive);

      final id2 = await dbHelper.insertUser(user2);
      expect(id2, 0);

      final db = await dbHelper.database;
      final result = await db.query('users');
      expect(result.length, 1);
    });
  });
}