import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sinaliza_app_libras/providers/user_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';
import 'package:http/http.dart' as http; // Importe o http
import 'dart:convert'; // Importe o convert

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Assim que a tela abre, buscamos os dados mais recentes
    _refreshUserData();
  }

  // --- FUNÇÃO PARA ATUALIZAR OS DADOS (XP) ---
  Future<void> _refreshUserData() async {
    setState(() {
      _isLoading = true;
    });

    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return;

    // ATENÇÃO: Use '10.0.2.2' (Android) ou 'localhost' (Desktop)
    const String apiUrl = 'http://10.0.2.2:3000/users/me';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        // Atualiza o Provider com os dados novos (incluindo o XP novo)
        Provider.of<UserProvider>(context, listen: false).setUser(userData);
      }
    } catch (e) {
      print("Erro ao atualizar perfil: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    await _storage.delete(key: 'jwt_token');
    
    if (!mounted) return;
    Provider.of<UserProvider>(context, listen: false).clearUser();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        actions: [
          // Botão para atualizar manualmente, se quiser
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshUserData,
          )
        ],
      ),
      body: _isLoading && user == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50),
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      user?.name ?? 'Nome não encontrado',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      user?.email ?? 'E-mail não encontrado',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    
                    const SizedBox(height: 30),

                    // --- CARD DE PONTUAÇÃO (XP) ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Total de XP",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 5),
                          _isLoading 
                            ? const SizedBox(
                                height: 20, 
                                width: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2)
                              )
                            : Text(
                                "${user?.totalScore ?? 0}", // Exibe os pontos atualizados!
                                style: TextStyle(
                                  fontSize: 32, 
                                  fontWeight: FontWeight.bold, 
                                  color: Colors.blue[800]
                                ),
                              ),
                        ],
                      ),
                    ),
                    // ------------------------------

                    const Spacer(),

                    ElevatedButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sair (Logout)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red[700],
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}