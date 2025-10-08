import 'mysql_connection.dart';

class DatabaseInit {
  final MySQLConnection _db = MySQLConnection.instance;

  /// Initialize database and create tables
  Future<void> initialize() async {
    try {
      await _db.connect();
      await _createTables();
      print('✅ Banco de dados inicializado com sucesso!');
    } catch (e) {
      print('❌ Erro ao inicializar banco de dados: $e');
      rethrow;
    }
  }

  /// Create all necessary tables
  Future<void> _createTables() async {
    await _createUsersTable();
    await _createSignsTable();
    await _insertSampleData();
  }

  /// Create users table
  Future<void> _createUsersTable() async {
    await _db.query('''
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        phone VARCHAR(20),
        profile_image VARCHAR(500),
        user_type ENUM('student', 'teacher', 'admin') NOT NULL DEFAULT 'student',
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    ''');
    print('✅ Tabela users criada/verificada');
  }

  /// Create signs table
  Future<void> _createSignsTable() async {
    await _db.query('''
      CREATE TABLE IF NOT EXISTS signs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        word VARCHAR(255) NOT NULL,
        description TEXT,
        video_url VARCHAR(500),
        image_url VARCHAR(500),
        category VARCHAR(100) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    ''');
    print('✅ Tabela signs criada/verificada');
  }

  /// Insert sample data
  Future<void> _insertSampleData() async {
    // Check if data already exists
    final userCount = await _db.query('SELECT COUNT(*) as count FROM users');
    final signCount = await _db.query('SELECT COUNT(*) as count FROM signs');

    if (userCount.first.fields['count'] == 0) {
      await _insertSampleUsers();
    }

    if (signCount.first.fields['count'] == 0) {
      await _insertSampleSigns();
    }
  }

  /// Insert sample users
  Future<void> _insertSampleUsers() async {
    await _db.query('''
      INSERT INTO users (name, email, user_type) VALUES
      ('Admin Sistema', 'admin@sinaliza.com', 'admin'),
      ('Professor João', 'joao@professor.com', 'teacher'),
      ('Aluno Maria', 'maria@aluno.com', 'student')
    ''');
    print('✅ Dados de exemplo de usuários inseridos');
  }

  /// Insert sample signs
  Future<void> _insertSampleSigns() async {
    await _db.query('''
      INSERT INTO signs (word, description, category) VALUES
      ('Olá', 'Saudação básica em Libras', 'Saudações'),
      ('Obrigado', 'Agradecimento em Libras', 'Saudações'),
      ('Por favor', 'Pedido educado em Libras', 'Saudações'),
      ('Água', 'Sinal para água', 'Objetos'),
      ('Comida', 'Sinal para comida', 'Objetos'),
      ('Casa', 'Sinal para casa', 'Lugares'),
      ('Escola', 'Sinal para escola', 'Lugares'),
      ('Família', 'Sinal para família', 'Pessoas'),
      ('Amigo', 'Sinal para amigo', 'Pessoas'),
      ('Trabalho', 'Sinal para trabalho', 'Atividades')
    ''');
    print('✅ Dados de exemplo de sinais inseridos');
  }

  /// Test database connection
  Future<bool> testConnection() async {
    try {
      return await _db.testConnection();
    } catch (e) {
      print('❌ Erro no teste de conexão: $e');
      return false;
    }
  }

  /// Close database connection
  Future<void> close() async {
    await _db.close();
  }
}