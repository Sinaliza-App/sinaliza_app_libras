import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:bcrypt/bcrypt.dart'; // Pacote para segurança da senha

class DBLibras {
  // Construtor privado e instância estática (Padrão Singleton)
  DBLibras._();
  static final DBLibras instance = DBLibras._();
  static Database? _database;

  Future<Database> get database async {

    if (_database != null) return _database!;
    
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sinaliza_app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      // Habilita chaves estrangeiras, essencial para a integridade dos dados
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // Método chamado na criação do banco de dados para definir a estrutura inicial
  Future<void> _onCreate(Database db, int version) async {
    // Executa a criação de todas as tabelas em ordem de dependência
    await db.execute(_usuarios);
    await db.execute(_categorias);
    await db.execute(_licoes);
    await db.execute(_sinais);
    await db.execute(_progressoSinal);
    await db.execute(_progressoLicao);
  }

  // --- ESTRUTURA DAS TABELAS (SQL) ---

  String get _usuarios => '''
    CREATE TABLE usuarios (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nome TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      senha TEXT NOT NULL,
      pontos INTEGER DEFAULT 0
    );
  ''';

  String get _categorias => '''
    CREATE TABLE categorias (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nome TEXT NOT NULL UNIQUE,
      descricao TEXT
    );
  ''';

  String get _licoes => '''
    CREATE TABLE licoes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nome TEXT NOT NULL,
      categoria_id INTEGER NOT NULL,
      ordem INTEGER DEFAULT 1,
      FOREIGN KEY (categoria_id) REFERENCES categorias(id) ON DELETE CASCADE
    );
  ''';

  String get _sinais => '''
    CREATE TABLE sinais (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nome TEXT NOT NULL,
      url_recurso TEXT NOT NULL,
      licao_id INTEGER NOT NULL,
      FOREIGN KEY (licao_id) REFERENCES licoes(id) ON DELETE CASCADE
    );
  ''';
  
  String get _progressoSinal => '''
    CREATE TABLE progresso_sinal (
      usuario_id INTEGER NOT NULL,
      sinal_id INTEGER NOT NULL,
      aprendido INTEGER DEFAULT 0,
      favorito INTEGER DEFAULT 0,
      acertos INTEGER DEFAULT 0,
      erros INTEGER DEFAULT 0,
      FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
      FOREIGN KEY (sinal_id) REFERENCES sinais(id) ON DELETE CASCADE,
      PRIMARY KEY (usuario_id, sinal_id)
    );
  ''';

  String get _progressoLicao => '''
      CREATE TABLE progresso_licao (
        usuario_id INTEGER NOT NULL,
        licao_id INTEGER NOT NULL,
        concluida INTEGER DEFAULT 0,
        pontuacao INTEGER DEFAULT 0,
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
        FOREIGN KEY (licao_id) REFERENCES licoes(id) ON DELETE CASCADE,
        PRIMARY KEY (usuario_id, licao_id)
      );
  ''';


  // --- MÉTODOS DE AUTENTICAÇÃO E USUÁRIO ---

  Future<int> cadastrarUsuario(String nome, String email, String senha) async {
    final db = await instance.database;
    final String senhaHash = BCrypt.hashpw(senha, BCrypt.gensalt());

    return await db.insert('usuarios', {
      'nome': nome,
      'email': email.toLowerCase(),
      'senha': senhaHash,
    }, conflictAlgorithm: ConflictAlgorithm.fail);
  }

  Future<Map<String, dynamic>?> fazerLogin(String email, String senha) async {
    final db = await instance.database;
    final result = await db.query(
      'usuarios',
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );

    if (result.isNotEmpty) {
      final user = result.first;
      final String senhaDoBanco = user['senha'] as String;
      if (BCrypt.checkpw(senha, senhaDoBanco)) {
        return Map<String, dynamic>.from(user)..remove('senha');
      }
    }
    return null;
  }
  
  Future<void> adicionarPontos(int usuarioId, int pontosGanhos) async {
      final db = await instance.database;
      await db.rawUpdate(
          'UPDATE usuarios SET pontos = pontos + ? WHERE id = ?',
          [pontosGanhos, usuarioId]
      );
  }
}