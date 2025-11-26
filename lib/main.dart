import 'package:flutter/material.dart';
import 'dart:io'; // Verificar plataforma (Windows, etc.)
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Banco FFI p/ desktop
import 'package:sinaliza_app_libras/views/splash_screen.dart'; // Tela inicial
import 'package:provider/provider.dart';
import 'package:sinaliza_app_libras/providers/user_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Corrige erro "databaseFactory not initialized" em desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => UserProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sinaliza App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
