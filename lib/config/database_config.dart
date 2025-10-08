import 'package:flutter_dotenv/flutter_dotenv.dart';

class DatabaseConfig {
  static String get host => dotenv.env['DB_HOST'] ?? 'localhost';
  static int get port => int.tryParse(dotenv.env['DB_PORT'] ?? '3306') ?? 3306;
  static String get database => dotenv.env['DB_NAME'] ?? 'sinaliza_libras';
  static String get username => dotenv.env['DB_USER'] ?? 'root';
  static String get password => dotenv.env['DB_PASSWORD'] ?? '';
  static String get charset => dotenv.env['DB_CHARSET'] ?? 'utf8mb4';
  
  static Map<String, dynamic> get connectionParams => {
    'host': host,
    'port': port,
    'user': username,
    'password': password,
    'db': database,
    'charset': charset,
  };
}