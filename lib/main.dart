import 'package:flutter/material.dart';
import 'dart:io'; // Importa para verificar a plataforma (Windows, etc.)
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Importa o FFI do SQFlite
import 'package:sinaliza_app_libras/views/splash_screen.dart'; // 1. Importa a nova SplashScreen

Future<void> main() async {
  // Garante que os bindings do Flutter estejam prontos
  WidgetsFlutterBinding.ensureInitialized(); 

  // Bloco de código que resolve o erro do banco de dados em Desktop
  // (como o erro 'databaseFactory not initialized')
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sinaliza App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false, // Opcional: remove a faixa "DEBUG"
      // 2. Define a SplashScreen como a nova tela inicial do aplicativo
      home: const SplashScreen(),
    );
  }
}