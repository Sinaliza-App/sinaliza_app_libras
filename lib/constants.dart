import 'package:flutter_dotenv/flutter_dotenv.dart';

// Troque aqui e muda no app todo!
String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'https://sinaliza-api-cn07.onrender.com';
const String wsBaseUrl = 'ws://192.168.0.5:8080';
