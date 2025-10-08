import 'package:mysql1/mysql1.dart';
import '../config/database_config.dart';

class MySQLConnection {
  static MySQLConnection? _instance;
  ConnectionSettings? _settings;
  MySqlConnection? _connection;

  MySQLConnection._();

  static MySQLConnection get instance {
    _instance ??= MySQLConnection._();
    return _instance!;
  }

  /// Initialize database connection settings
  void initialize() {
    _settings = ConnectionSettings(
      host: DatabaseConfig.host,
      port: DatabaseConfig.port,
      user: DatabaseConfig.username,
      password: DatabaseConfig.password,
      db: DatabaseConfig.database,
    );
  }

  /// Get database connection
  Future<MySqlConnection> get connection async {
    if (_connection == null) {
      await connect();
    }
    return _connection!;
  }

  /// Connect to database
  Future<void> connect() async {
    try {
      if (_settings == null) {
        initialize();
      }
      _connection = await MySqlConnection.connect(_settings!);
      print('✅ Conectado ao MySQL com sucesso!');
    } catch (e) {
      print('❌ Erro ao conectar ao MySQL: $e');
      rethrow;
    }
  }

  /// Execute a query
  Future<Results> query(String sql, [List<Object?>? values]) async {
    try {
      final conn = await connection;
      return await conn.query(sql, values);
    } catch (e) {
      print('❌ Erro ao executar query: $e');
      rethrow;
    }
  }

  /// Execute a prepared statement
  Future<Results> prepared(String sql, [List<Object?>? values]) async {
    try {
      final conn = await connection;
      return await conn.query(sql, values);
    } catch (e) {
      print('❌ Erro ao executar prepared statement: $e');
      rethrow;
    }
  }

  /// Close database connection
  Future<void> close() async {
    try {
      await _connection?.close();
      _connection = null;
      print('✅ Conexão MySQL fechada com sucesso!');
    } catch (e) {
      print('❌ Erro ao fechar conexão MySQL: $e');
    }
  }

  /// Test database connection
  Future<bool> testConnection() async {
    try {
      await connect();
      final result = await query('SELECT 1 as test');
      return result.isNotEmpty;
    } catch (e) {
      print('❌ Teste de conexão falhou: $e');
      return false;
    }
  }

  /// Check if connection is active
  bool get isConnected => _connection != null;
}