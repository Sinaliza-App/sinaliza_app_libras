class DatabaseConfigExemple {
  static const String host = 'localhost';
  static const String port = '3306';
  static const String database = 'sinaliza_app_libras';
  static const String username = 'root';
  static const String password = '';
  static const String charset = 'utf8mb4';
  static const String collation = 'utf8mb4_unicode_ci';

  static Map<String, String> get config => {
    'host': host,
    'port': port,
    'database': database,
    'user': username,
    'password': password,
    'charset': charset,
    'db': database,
    };

  
  }