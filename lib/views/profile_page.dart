import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sinaliza_app_libras/providers/user_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart'; // Para navegar no logout

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // Função de Logout
  Future<void> _logout(BuildContext context) async {
    // 1. Limpa o token salvo
    final storage = const FlutterSecureStorage();
    await storage.delete(key: 'jwt_token');

    // 2. Limpa o usuário do estado global (Provider)
    // Usamos listen: false aqui porque estamos dentro de uma função
    Provider.of<UserProvider>(context, listen: false).clearUser();

    // 3. Navega de volta para a tela de Login e remove todas as
    //    telas anteriores (para que o usuário não possa "voltar")
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false, // Remove todas as telas
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Lê o UserProvider para obter os dados do usuário
    //    Usamos 'watch' aqui (que é o padrão) para que a tela
    //    se atualize se os dados do usuário mudarem.
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user; // Pega o objeto UserModel

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 2. Exibe os dados do usuário
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 20),
              Text(
                user?.name ?? 'Nome não encontrado', // Mostra o nome
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? 'E-mail não encontrado', // Mostra o e-mail
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 30),

              // 3. Botão de Logout
              ElevatedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sair (Logout)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}