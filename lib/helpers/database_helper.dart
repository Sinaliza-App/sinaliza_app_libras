import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Padrão Singleton para garantir uma única instância do banco de dados.
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'sinaliza.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE lessons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        lessonId INTEGER,
        score INTEGER,
        FOREIGN KEY (userId) REFERENCES users (id),
        FOREIGN KEY (lessonId) REFERENCES lessons (id)
      )
    ''');

    await db.insert('lessons', {
      'title': 'Alfabeto: Letra A',
      'description': 'Aprenda o sinal da primeira letra do alfabeto.',
    });
    await db.insert('lessons', {
      'title': 'Alfabeto: Letra B',
      'description': 'Continue seus estudos com a letra B.',
    });
    await db.insert('lessons', {
      'title': 'Saudações: Oi',
      'description':
          'Um dos sinais mais importantes para iniciar uma conversa.',
    });
    await db.insert('lessons', {
      'title': 'Saudações: Tudo bem?',
      'description': 'Aprenda a perguntar como alguém está.',
    });
  }

  Future<int> insertUser(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(
      'users',
      row,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> insertLesson(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('lessons', row);
  }

  Future<List<Map<String, dynamic>>> getLessons() async {
    final db = await database;
    return await db.query('lessons');
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // U(pdate) - Atualizar os dados de um usuário
  Future<int> updateUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.update(
      'users',
      user,
      where: 'id = ?',
      whereArgs: [user['id']],
    );
  }

  // D(elete) - Deletar um usuário
  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> saveOrUpdateProgress(Map<String, dynamic> progress) async {
    final db = await database;

    return await db.insert(
      'progress',
      progress,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getProgressForUser(int userId) async {
    final db = await database;
    return await db.query('progress', where: 'userId = ?', whereArgs: [userId]);
  }

  Future<int> deleteProgress(int id) async {
    final db = await database;
    return await db.delete('progress', where: 'id = ?', whereArgs: [id]);
  }
}
