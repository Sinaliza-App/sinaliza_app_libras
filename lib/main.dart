import 'package:flutter/material.dart';
import 'dart:io'; // Para verificar a plataforma
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Para banco de dados no PC
import 'package:sinaliza_app_libras/views/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:sinaliza_app_libras/providers/user_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:sinaliza_app_libras/theme/app_theme.dart';
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Garante que o Flutter esteja pronto antes de rodar código
  WidgetsFlutterBinding.ensureInitialized();

  // Configuração para rodar banco de dados no Windows/Linux/Mac
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  runApp(
    // Injetamos o UserProvider no topo da árvore para o estado global
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
      navigatorKey: navigatorKey,
      title: 'Sinaliza App',
      
      theme: AppTheme.darkTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      
      debugShowCheckedModeBanner: false, // Remove a faixa "DEBUG"
      home: const SplashScreen(), // Começa pela tela de carregamento
    );
  }
}