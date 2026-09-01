import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sinaliza_app_libras/theme/app_colors.dart';
import 'package:sinaliza_app_libras/widgets/custom_snackbar.dart';
import 'package:sinaliza_app_libras/views/login_screen.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    final newPassword = _passwordController.text.trim();
    if (newPassword.length < 6) {
      CustomSnackBar.showWarning(context, 'A senha deve ter no mínimo 6 caracteres.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // O Supabase atualiza a senha do usuário que está logado atualmente
      // (a sessão foi criada automaticamente ao clicar no deep link)
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      if (!mounted) return;
      CustomSnackBar.showSuccess(context, 'Senha atualizada com sucesso!');
      
      // Desloga o usuário e redireciona para o login
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<dynamic>(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, 'Erro ao atualizar a senha.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBG,
      appBar: AppBar(title: const Text('Nova Senha', style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Digite sua nova senha abaixo',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nova senha',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: AppColors.cardDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonBlue),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Salvar Senha', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
